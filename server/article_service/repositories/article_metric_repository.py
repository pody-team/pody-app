from sqlalchemy.ext.asyncio import AsyncSession

from models import ArticleMetric


class ArticleMetricRepository:
    """Repository luu metric tuong tac cua bai bao."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def track_metric(self, article_id: int, user_id: str, reading_time_seconds: int) -> None:
        """Luu mot su kien thoi gian doc de phan tich tuong tac ve sau."""
        self.session.add(
            ArticleMetric(
                article_id=article_id,
                user_id=user_id,
                reading_time_seconds=reading_time_seconds,
            )
        )
