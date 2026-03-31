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

    favorite_category_limit = 5

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

    async def list_articles(self, limit: int, offset: int, category=None, query=None, current_user_id=None) -> dict:
        results = await self.query_repository.list_articles_with_extra(
            limit=limit,
            offset=offset,
            category=category,
            query=query,
            current_user_id=current_user_id,
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

    async def list_favorite_categories(self, user_id: str) -> dict:
        categories = await self.query_repository.list_favorite_categories(user_id)
        return {
            "count": len(categories),
            "categories": [
                {
                    "id": category.id,
                    "slug": category.slug,
                    "name": clean_text(category.name),
                    "description": clean_text(category.description),
                }
                for category in categories
            ],
        }

    async def replace_favorite_categories(self, user_id: str, category_ids: list[str]) -> dict:
        normalized_category_ids = [category_id.strip() for category_id in category_ids if category_id.strip()]
        if not normalized_category_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one favorite category is required",
            )

        unique_category_ids = list(dict.fromkeys(normalized_category_ids))
        if len(unique_category_ids) > self.favorite_category_limit:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You can choose up to {self.favorite_category_limit} favorite categories",
            )

        categories = await self.query_repository.list_active_categories_by_ids(unique_category_ids)
        if len(categories) != len(unique_category_ids):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="One or more categories do not exist or are inactive",
            )

        ordered_categories = sorted(
            categories,
            key=lambda category: unique_category_ids.index(category.id),
        )
        saved_categories = await self.query_repository.replace_favorite_categories(
            user_id,
            [category.id for category in ordered_categories],
        )
        saved_category_map = {category.id: category for category in saved_categories}

        return {
            "count": len(ordered_categories),
            "categories": [
                {
                    "id": category.id,
                    "slug": saved_category_map[category.id].slug,
                    "name": clean_text(saved_category_map[category.id].name),
                    "description": clean_text(saved_category_map[category.id].description),
                }
                for category in ordered_categories
            ],
        }

    async def list_categories(self) -> dict:
        categories = await self.query_repository.list_categories_with_counts()
        return {
            "count": len(categories),
            "categories": [
                {
                    "id": category.id,
                    "slug": category.slug,
                    "name": clean_text(category.name),
                    "description": clean_text(category.description),
                    "article_count": article_count,
                }
                for category, article_count in categories
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
