from typing import List, Optional, Tuple

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, ArticleCategory, ArticleStat


class ArticleQueryRepository:
    """Read-side repository for article listing and detail views."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_articles_with_extra(
        self,
        limit: int = 20,
        offset: int = 0,
        category: Optional[str] = None,
        query: Optional[str] = None,
    ) -> List[Tuple[Article, Optional[str], int]]:
        stmt = (
            select(
                Article,
                ArticleCategory.category_name,
                func.coalesce(ArticleStat.view_count, 0),
            )
            .outerjoin(ArticleCategory, Article.id == ArticleCategory.article_id)
            .outerjoin(ArticleStat, Article.id == ArticleStat.article_id)
            .order_by(Article.published_at.desc())
        )

        if category:
            stmt = stmt.where(ArticleCategory.category_name == category)

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
                    func.array_agg(func.distinct(ArticleCategory.category_name)),
                    None,
                ).label("categories"),
                func.coalesce(ArticleStat.view_count, 0).label("view_count"),
            )
            .outerjoin(ArticleCategory, Article.id == ArticleCategory.article_id)
            .outerjoin(ArticleStat, Article.id == ArticleStat.article_id)
            .where(Article.id == article_id)
            .group_by(Article.id, ArticleStat.view_count)
        )
        result = await self.session.execute(stmt)
        row = result.first()
        if not row:
            return None

        return row[0], row.categories or [], row.view_count
