from datetime import datetime
from typing import Dict, Optional

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from models import ArticleInteraction


REACTION_TYPES = ("LIKE", "LOVE", "DISLIKE")


class ArticleReactionRepository:
    """Repository luu va tong hop reaction cua bai bao."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def add_interaction(self, article_id: int, user_id: str, interaction_type: str) -> None:
        """Upsert reaction hoac xoa khi nguoi dung bam lai reaction dang chon."""
        normalized_type = interaction_type.upper()
        current_stmt = select(ArticleInteraction).where(
            ArticleInteraction.article_id == article_id,
            ArticleInteraction.user_id == user_id,
        )
        current_result = await self.session.execute(current_stmt)
        current = current_result.scalar_one_or_none()

        if current and current.interaction_type == normalized_type:
            # Bam lai reaction dang active se duoc hieu la bo reaction.
            await self.session.execute(delete(ArticleInteraction).where(ArticleInteraction.id == current.id))
            return

        # PostgreSQL upsert giu duy nhat mot reaction cho moi cap article-user.
        stmt = insert(ArticleInteraction).values(
            article_id=article_id,
            user_id=user_id,
            interaction_type=normalized_type,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[ArticleInteraction.article_id, ArticleInteraction.user_id],
            set_={
                "interaction_type": normalized_type,
                "updated_at": datetime.utcnow(),
            },
        )
        await self.session.execute(stmt)

    async def get_reaction_summary(self, article_id: int, user_id: Optional[str] = None) -> Dict[str, object]:
        """Tong hop so reaction va co the kem reaction cua nguoi dung hien tai."""
        stmt = select(
            func.count().filter(ArticleInteraction.interaction_type == "LIKE").label("like_count"),
            func.count().filter(ArticleInteraction.interaction_type == "LOVE").label("love_count"),
            func.count().filter(ArticleInteraction.interaction_type == "DISLIKE").label("dislike_count"),
            func.count(ArticleInteraction.id).label("total_count"),
        ).where(ArticleInteraction.article_id == article_id)
        result = await self.session.execute(stmt)
        row = result.one()

        current_user_reaction = None
        if user_id is not None:
            user_stmt = select(ArticleInteraction.interaction_type).where(
                ArticleInteraction.article_id == article_id,
                ArticleInteraction.user_id == user_id,
            )
            user_result = await self.session.execute(user_stmt)
            current_user_reaction = user_result.scalar_one_or_none()

        return {
            "like_count": row.like_count or 0,
            "love_count": row.love_count or 0,
            "dislike_count": row.dislike_count or 0,
            "total_count": row.total_count or 0,
            "current_user_reaction": current_user_reaction,
        }
