from typing import List, Optional, Tuple

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, ArticleStat, Category, CategoryArticle
from utils.category_slug import build_category_slug


class ArticleQueryRepository:
    """Read-side repository for article listing and detail views."""

    def __init__(self, session: AsyncSession):
        self.session = session

    @staticmethod
    def _category_source_priority():
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
    ) -> List[Tuple[Article, Optional[str], int]]:
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
            .order_by(Article.published_at.desc())
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

        result = await self.session.execute(stmt.limit(limit).offset(offset))
        return [(row[0], row[1], row[2]) for row in result.all()]

    async def get_article_detail(self, article_id: int) -> Optional[Tuple[Article, List[str], int]]:
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
