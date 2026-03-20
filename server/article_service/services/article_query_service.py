from fastapi import HTTPException, status

from repositories import (
    ArticleCommentRepository,
    ArticleQueryRepository,
    ArticleReactionRepository,
    ArticleStatsRepository,
    ArticleWriteRepository,
)
from schemas import CommentResponse, clean_text


class ArticleQueryService:
    """Application service for article read use cases."""

    def __init__(
        self,
        write_repository: ArticleWriteRepository,
        query_repository: ArticleQueryRepository,
        stats_repository: ArticleStatsRepository,
        reaction_repository: ArticleReactionRepository,
        comment_repository: ArticleCommentRepository,
    ):
        self.write_repository = write_repository
        self.query_repository = query_repository
        self.stats_repository = stats_repository
        self.reaction_repository = reaction_repository
        self.comment_repository = comment_repository

    async def ensure_article_exists(self, article_id: int):
        article = await self.write_repository.get_by_id(article_id)
        if not article:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
        return article

    async def list_articles(self, limit: int, offset: int, category=None, query=None) -> dict:
        results = await self.query_repository.list_articles_with_extra(
            limit=limit,
            offset=offset,
            category=category,
            query=query,
        )
        return {
            "count": len(results),
            "limit": limit,
            "offset": offset,
            "articles": [
                {
                    "id": article.id,
                    "title": clean_text(article.title),
                    "summary": clean_text(article.summary),
                    "author": clean_text(article.author),
                    "category": category_name,
                    "view_count": views,
                    "thumbnail_url": article.thumbnail_url,
                    "original_url": article.original_url,
                    "published_at": article.published_at.isoformat() if article.published_at else None,
                    "source_id": article.source_id,
                    "status": article.status,
                }
                for article, category_name, views in results
            ],
        }

    async def get_article_detail(self, article_id: int, current_user_id=None) -> dict:
        detail = await self.query_repository.get_article_detail(article_id)
        if not detail:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")

        article, categories, view_count = detail
        await self.stats_repository.increment_view_count(article_id)
        reactions = await self.reaction_repository.get_reaction_summary(article_id, user_id=current_user_id)
        comments_count = await self.comment_repository.count_comments(article_id)

        return {
            "id": article.id,
            "title": clean_text(article.title),
            "content": article.content,
            "summary": clean_text(article.summary),
            "author": clean_text(article.author),
            "categories": categories,
            "view_count": view_count + 1,
            "comments_count": comments_count,
            "thumbnail_url": article.thumbnail_url,
            "original_url": article.original_url,
            "published_at": article.published_at.isoformat() if article.published_at else None,
            "source_id": article.source_id,
            "reactions": reactions,
            "is_liked": reactions["current_user_reaction"] == "LIKE",
            "is_loved": reactions["current_user_reaction"] == "LOVE",
            "is_disliked": reactions["current_user_reaction"] == "DISLIKE",
        }

    async def get_reactions(self, article_id: int, current_user_id=None) -> dict:
        await self.ensure_article_exists(article_id)
        reactions = await self.reaction_repository.get_reaction_summary(article_id, user_id=current_user_id)
        return {"article_id": article_id, "reactions": reactions}

    async def list_comments(self, article_id: int, limit: int, offset: int) -> dict:
        await self.ensure_article_exists(article_id)
        comments = await self.comment_repository.list_comments(article_id, limit=limit, offset=offset)
        total = await self.comment_repository.count_comments(article_id)
        return {
            "count": len(comments),
            "total": total,
            "limit": limit,
            "offset": offset,
            "comments": [CommentResponse.model_validate(comment).model_dump(mode="json") for comment in comments],
        }
