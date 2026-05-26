from typing import List, Optional, Tuple

from sqlalchemy import and_, case, delete, func, insert, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, ArticleStat, Category, CategoryArticle, CategoryUser
from utils.category_slug import build_category_slug


class ArticleQueryRepository:
    """Repository doc du lieu cho danh sach, chi tiet bai bao va category."""

    def __init__(self, session: AsyncSession):
        self.session = session

    @staticmethod
    def _category_source_priority():
        """Uu tien category semantic hon manual khi chon nhan hien thi chinh."""
        return case(
            (CategoryArticle.assignment_source == "semantic", 0),
            else_=1,
        )

    async def list_articles_with_extra(
        self,
        limit: int = 20,
        offset: int = 0,
        category: Optional[str] = None,
        query: Optional[str] = None,
        current_user_id: Optional[str] = None,
    ) -> List[Tuple[Article, Optional[str], int]]:
        """Truy van feed voi bo loc tuy chon va uu tien category yeu thich."""
        primary_category_subquery = (
            select(
                CategoryArticle.article_id.label("article_id"),
                Category.name.label("primary_category"),
                func.row_number()
                .over(
                    partition_by=CategoryArticle.article_id,
                    order_by=(
                        self._category_source_priority().asc(),
                        CategoryArticle.is_primary.desc(),
                        CategoryArticle.match_rank.asc().nullslast(),
                        Category.name.asc(),
                    ),
                )
                .label("category_rank"),
            )
            .join(Category, Category.id == CategoryArticle.category_id)
            .where(Category.is_active.is_(True))
            .subquery()
        )

        stmt = (
            select(
                Article,
                primary_category_subquery.c.primary_category,
                func.coalesce(ArticleStat.view_count, 0),
            )
            .outerjoin(
                primary_category_subquery,
                and_(
                    primary_category_subquery.c.article_id == Article.id,
                    primary_category_subquery.c.category_rank == 1,
                ),
            )
            .outerjoin(ArticleStat, Article.id == ArticleStat.article_id)
        )

        if category:
            normalized_category = category.strip()
            category_slug = build_category_slug(normalized_category)
            category_exists = (
                select(CategoryArticle.id)
                .join(Category, Category.id == CategoryArticle.category_id)
                .where(
                    CategoryArticle.article_id == Article.id,
                    Category.is_active.is_(True),
                    or_(
                        func.lower(Category.name) == normalized_category.lower(),
                        Category.slug == category_slug,
                    ),
                )
                .exists()
            )
            stmt = stmt.where(category_exists)

        if query:
            search_query = f"%{query}%"
            stmt = stmt.where(
                or_(
                    Article.title.ilike(search_query),
                    Article.summary.ilike(search_query),
                )
            )

        should_prioritize_favorites = bool(
            current_user_id and current_user_id.strip() and not category and not query
        )
        if should_prioritize_favorites:
            # Feed ca nhan hoa: bai thuoc category yeu thich duoc sap xep len truoc.
            primary_favorite_match_exists = (
                select(CategoryUser.id)
                .join(Category, Category.id == CategoryUser.category_id)
                .join(
                    CategoryArticle,
                    and_(
                        CategoryArticle.category_id == CategoryUser.category_id,
                        CategoryArticle.article_id == Article.id,
                        CategoryArticle.is_primary.is_(True),
                    ),
                )
                .where(
                    CategoryUser.user_id == current_user_id.strip(),
                    Category.is_active.is_(True),
                )
                .exists()
            )
            favorite_match_exists = (
                select(CategoryUser.id)
                .join(Category, Category.id == CategoryUser.category_id)
                .join(
                    CategoryArticle,
                    and_(
                        CategoryArticle.category_id == CategoryUser.category_id,
                        CategoryArticle.article_id == Article.id,
                    ),
                )
                .where(
                    CategoryUser.user_id == current_user_id.strip(),
                    Category.is_active.is_(True),
                )
                .exists()
            )
            stmt = stmt.order_by(
                case((primary_favorite_match_exists, 0), else_=1).asc(),
                case((favorite_match_exists, 0), else_=1).asc(),
                Article.published_at.desc(),
            )
        else:
            stmt = stmt.order_by(Article.published_at.desc())

        result = await self.session.execute(stmt.limit(limit).offset(offset))
        return [(row[0], row[1], row[2]) for row in result.all()]

    async def get_article_detail(self, article_id: int) -> Optional[Tuple[Article, List[str], int]]:
        """Lay mot bai bao kem category dang hoat dong va so luot xem hien tai."""
        stmt = (
            select(
                Article,
                func.array_remove(
                    func.array_agg(
                        func.distinct(Category.name)
                    ),
                    None,
                ).label("categories"),
                func.coalesce(ArticleStat.view_count, 0).label("view_count"),
            )
            .outerjoin(CategoryArticle, Article.id == CategoryArticle.article_id)
            .outerjoin(
                Category,
                and_(
                    Category.id == CategoryArticle.category_id,
                    Category.is_active.is_(True),
                ),
            )
            .outerjoin(ArticleStat, Article.id == ArticleStat.article_id)
            .where(Article.id == article_id)
            .group_by(Article.id, ArticleStat.view_count)
        )
        result = await self.session.execute(stmt)
        row = result.first()
        if not row:
            return None

        return row[0], row.categories or [], row.view_count

    async def list_categories_with_counts(self) -> List[Tuple[Category, int]]:
        """Tra ve category dang hoat dong, sap xep theo so bai bao lien ket."""
        article_count = func.count(func.distinct(CategoryArticle.article_id))
        stmt = (
            select(
                Category,
                article_count.label("article_count"),
            )
            .outerjoin(CategoryArticle, Category.id == CategoryArticle.category_id)
            .outerjoin(Article, Article.id == CategoryArticle.article_id)
            .where(Category.is_active.is_(True))
            .group_by(Category.id)
            .order_by(article_count.desc(), Category.name.asc())
        )

        result = await self.session.execute(stmt)
        return [(row[0], row.article_count) for row in result.all()]

    async def list_favorite_categories(self, user_id: str) -> List[Category]:
        """Lay cac category yeu thich dang hoat dong cua nguoi dung."""
        stmt = (
            select(Category)
            .join(CategoryUser, CategoryUser.category_id == Category.id)
            .where(
                CategoryUser.user_id == user_id,
                Category.is_active.is_(True),
            )
            .order_by(Category.name.asc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def list_active_categories_by_ids(self, category_ids: list[str]) -> List[Category]:
        """Kiem tra cac category id gui len co nam trong category dang hoat dong."""
        if not category_ids:
            return []

        stmt = (
            select(Category)
            .where(
                Category.id.in_(category_ids),
                Category.is_active.is_(True),
            )
            .order_by(Category.name.asc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def replace_favorite_categories(self, user_id: str, category_ids: list[str]) -> List[Category]:
        """Thay the toan bo category yeu thich da luu cua mot nguoi dung."""
        await self.session.execute(delete(CategoryUser).where(CategoryUser.user_id == user_id))
        if category_ids:
            await self.session.execute(
                insert(CategoryUser),
                [{"user_id": user_id, "category_id": category_id} for category_id in category_ids],
            )
        return await self.list_favorite_categories(user_id)
