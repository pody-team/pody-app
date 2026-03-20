from datetime import datetime

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from models import ArticleStat


class ArticleStatsRepository:
    """Repository for article stat counters."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def increment_view_count(self, article_id: int) -> None:
        stmt = insert(ArticleStat).values(
            article_id=article_id,
            view_count=1,
            updated_at=datetime.utcnow(),
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[ArticleStat.article_id],
            set_={
                "view_count": ArticleStat.view_count + 1,
                "updated_at": datetime.utcnow(),
            },
        )
        await self.session.execute(stmt)
