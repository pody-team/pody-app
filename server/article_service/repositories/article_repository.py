from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from .article_comment_repository import ArticleCommentRepository
from .article_metric_repository import ArticleMetricRepository
from .article_query_repository import ArticleQueryRepository
from .article_reaction_repository import ArticleReactionRepository, REACTION_TYPES
from .article_stats_repository import ArticleStatsRepository
from .article_write_repository import ArticleWriteRepository


class ArticleRepository:
    """
    Backward-compatible facade that delegates to focused repositories.
    Keep crawler and older call sites stable while newer code uses smaller repos/services.
    """

    def __init__(self, session: AsyncSession):
        self.session = session
        self.write = ArticleWriteRepository(session)
        self.query = ArticleQueryRepository(session)
        self.stats = ArticleStatsRepository(session)
        self.reactions = ArticleReactionRepository(session)
        self.metrics = ArticleMetricRepository(session)
        self.comments = ArticleCommentRepository(session)

    async def get_by_id(self, article_id: int):
        return await self.write.get_by_id(article_id)

    async def exists_by_url(self, original_url: str) -> bool:
        return await self.write.exists_by_url(original_url)

    async def insert_article(
        self,
        title: str,
        original_url: str,
        source_id: int,
        content: Optional[str] = None,
        author: Optional[str] = None,
        summary: Optional[str] = None,
        thumbnail_url: Optional[str] = None,
        published_at=None,
        status: str = "PUBLISHED",
    ):
        return await self.write.insert_article(
            title=title,
            original_url=original_url,
            source_id=source_id,
            content=content,
            author=author,
            summary=summary,
            thumbnail_url=thumbnail_url,
            published_at=published_at,
            status=status,
        )

    async def add_category(
        self,
        article_id: int,
        category_name: str,
        description: Optional[str] = None,
        is_primary: Optional[bool] = None,
    ) -> None:
        await self.write.add_category(
            article_id,
            category_name,
            description=description,
            is_primary=is_primary,
        )

    async def list_articles_with_extra(self, limit: int = 20, offset: int = 0, category=None, query=None):
        return await self.query.list_articles_with_extra(limit=limit, offset=offset, category=category, query=query)

    async def get_article_detail(self, article_id: int):
        return await self.query.get_article_detail(article_id)

    async def increment_view_count(self, article_id: int) -> None:
        await self.stats.increment_view_count(article_id)

    async def add_interaction(self, article_id: int, user_id: str, interaction_type: str) -> None:
        await self.reactions.add_interaction(article_id, user_id, interaction_type)

    async def get_reaction_summary(self, article_id: int, user_id=None):
        return await self.reactions.get_reaction_summary(article_id, user_id=user_id)

    async def track_metric(self, article_id: int, user_id: str, reading_time_seconds: int) -> None:
        await self.metrics.track_metric(article_id, user_id, reading_time_seconds)

    async def add_comment(self, article_id: int, user_id: str, content: str, user_name=None):
        return await self.comments.add_comment(article_id, user_id, content, user_name=user_name)

    async def list_comments(self, article_id: int, limit: int = 20, offset: int = 0):
        return await self.comments.list_comments(article_id, limit=limit, offset=offset)

    async def count_comments(self, article_id: int) -> int:
        return await self.comments.count_comments(article_id)


__all__ = ["ArticleRepository", "REACTION_TYPES"]
