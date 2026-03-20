from datetime import datetime
from typing import List, Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import ArticleComment


class ArticleCommentRepository:
    """Repository for article comments."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def add_comment(
        self,
        article_id: int,
        user_id: str,
        content: str,
        user_name: Optional[str] = None,
    ) -> ArticleComment:
        comment = ArticleComment(
            article_id=article_id,
            user_id=user_id,
            user_name=user_name,
            content=content.strip(),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        self.session.add(comment)
        await self.session.flush()
        await self.session.refresh(comment)
        return comment

    async def list_comments(self, article_id: int, limit: int = 20, offset: int = 0) -> List[ArticleComment]:
        stmt = (
            select(ArticleComment)
            .where(ArticleComment.article_id == article_id)
            .order_by(ArticleComment.created_at.desc(), ArticleComment.id.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count_comments(self, article_id: int) -> int:
        stmt = select(func.count(ArticleComment.id)).where(ArticleComment.article_id == article_id)
        result = await self.session.execute(stmt)
        return result.scalar_one() or 0
