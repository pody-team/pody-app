from fastapi import HTTPException, status

from repositories import (
    ArticleCommentRepository,
    ArticleMetricRepository,
    ArticleReactionRepository,
    ArticleWriteRepository,
    REACTION_TYPES,
)
from schemas import CommentResponse


class ArticleEngagementService:
    """Application service for article engagement use cases."""

    def __init__(
        self,
        write_repository: ArticleWriteRepository,
        reaction_repository: ArticleReactionRepository,
        metric_repository: ArticleMetricRepository,
        comment_repository: ArticleCommentRepository,
    ):
        self.write_repository = write_repository
        self.reaction_repository = reaction_repository
        self.metric_repository = metric_repository
        self.comment_repository = comment_repository

    async def ensure_article_exists(self, article_id: int):
        article = await self.write_repository.get_by_id(article_id)
        if not article:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
        return article

    @staticmethod
    def normalize_reaction_type(value: str) -> str:
        reaction_type = value.strip().upper()
        if reaction_type not in REACTION_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"unsupported reaction type: {reaction_type}",
            )
        return reaction_type

    async def add_reaction(self, article_id: int, user_id: str, reaction_type: str) -> dict:
        await self.ensure_article_exists(article_id)
        normalized_type = self.normalize_reaction_type(reaction_type)
        await self.reaction_repository.add_interaction(article_id, user_id, normalized_type)
        reactions = await self.reaction_repository.get_reaction_summary(article_id, user_id=user_id)
        return {
            "status": "success",
            "article_id": article_id,
            "user_id": user_id,
            "reaction": reactions["current_user_reaction"],
            "reactions": reactions,
        }

    async def track_metric(self, article_id: int, user_id: str, reading_time_seconds: int) -> dict:
        await self.ensure_article_exists(article_id)
        await self.metric_repository.track_metric(article_id, user_id, reading_time_seconds)
        return {"status": "success", "message": "Metric tracked"}

    async def create_comment(self, article_id: int, user_id: str, content: str, user_name=None) -> dict:
        await self.ensure_article_exists(article_id)
        normalized_content = content.strip()
        if not normalized_content:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="comment content is required")

        comment = await self.comment_repository.add_comment(
            article_id=article_id,
            user_id=user_id,
            content=normalized_content,
            user_name=user_name,
        )
        total = await self.comment_repository.count_comments(article_id)
        return {
            "comment": CommentResponse.model_validate(comment).model_dump(mode="json"),
            "comments_count": total,
        }
