from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.gzip import GZipMiddleware

from ai_podcast.router import router as ai_podcast_router
from dependencies import (
    get_article_engagement_service,
    get_article_query_service,
    get_optional_auth_user,
    resolve_user_id,
)
from schemas import (
    AuthenticatedUser,
    CommentCreateRequest,
    FavoriteCategoriesUpdateRequest,
    MetricRequest,
    ReactionRequest,
)
from services import ArticleEngagementService, ArticleQueryService


def create_api(logger) -> FastAPI:
    api = FastAPI(title="Pody Article Service", version="1.1.0")
    api.add_middleware(GZipMiddleware, minimum_size=1024)
    api.include_router(ai_podcast_router)

    @api.get("/healthz")
    async def healthz():
        from datetime import datetime

        return {"status": "ok", "timestamp": datetime.now().isoformat()}

    @api.get("/api/v1/article")
    async def list_articles(
        limit: int = Query(50, ge=1, le=100),
        offset: int = Query(0, ge=0),
        category: Optional[str] = Query(None, description="Filter by category"),
        q: Optional[str] = Query(None, description="Search keyword in title/summary"),
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            return await article_query_service.list_articles(
                limit=limit,
                offset=offset,
                category=category,
                query=q,
                current_user_id=auth_user.user_id if auth_user else None,
            )
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error fetching articles: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    # Keep static category routes registered before the dynamic article-id route.
    # Starlette/FastAPI path matching is order-sensitive, so `/categories`
    # must be handled here instead of falling through to `/{article_id}`.
    @api.get("/api/v1/article/categories")
    @api.get("/api/v1/article/categories/")
    async def list_categories(
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
    ):
        try:
            return await article_query_service.list_categories()
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error fetching article categories: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.get("/api/v1/article/me/preferences/categories")
    async def list_favorite_categories(
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            user_id = resolve_user_id(auth_user, None)
            return await article_query_service.list_favorite_categories(user_id)
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error fetching favorite categories: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.put("/api/v1/article/me/preferences/categories")
    async def replace_favorite_categories(
        req: FavoriteCategoriesUpdateRequest,
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            user_id = resolve_user_id(auth_user, None)
            return await article_query_service.replace_favorite_categories(user_id, req.category_ids)
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error updating favorite categories: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.get("/api/v1/article/{article_id}")
    async def get_article(
        article_id: int,
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            return await article_query_service.get_article_detail(
                article_id=article_id,
                current_user_id=auth_user.user_id if auth_user else None,
            )
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error fetching article {article_id}: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.get("/api/v1/article/{article_id}/reactions")
    async def get_reactions(
        article_id: int,
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            return await article_query_service.get_reactions(
                article_id=article_id,
                current_user_id=auth_user.user_id if auth_user else None,
            )
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error fetching reactions: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.post("/api/v1/article/{article_id}/reactions")
    @api.post("/api/v1/article/{article_id}/interaction")
    async def add_reaction(
        article_id: int,
        req: ReactionRequest,
        article_engagement_service: ArticleEngagementService = Depends(get_article_engagement_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            user_id = resolve_user_id(auth_user)
            return await article_engagement_service.add_reaction(article_id, user_id, req.type)
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error adding interaction: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.post("/api/v1/article/{article_id}/metric")
    async def track_metric(
        article_id: int,
        req: MetricRequest,
        article_engagement_service: ArticleEngagementService = Depends(get_article_engagement_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            user_id = resolve_user_id(auth_user)
            return await article_engagement_service.track_metric(article_id, user_id, req.reading_time_seconds)
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error tracking metric: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.get("/api/v1/article/{article_id}/comments")
    async def list_comments(
        article_id: int,
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0),
        article_query_service: ArticleQueryService = Depends(get_article_query_service),
    ):
        try:
            return await article_query_service.list_comments(article_id=article_id, limit=limit, offset=offset)
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error listing comments: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    @api.post("/api/v1/article/{article_id}/comments", status_code=201)
    async def create_comment(
        article_id: int,
        req: CommentCreateRequest,
        article_engagement_service: ArticleEngagementService = Depends(get_article_engagement_service),
        auth_user: Optional[AuthenticatedUser] = Depends(get_optional_auth_user),
    ):
        try:
            user_id = resolve_user_id(auth_user)
            return await article_engagement_service.create_comment(
                article_id=article_id,
                user_id=user_id,
                content=req.content,
                user_name=auth_user.name if auth_user and auth_user.name else req.user_name,
            )
        except HTTPException:
            raise
        except Exception as exc:
            logger.error(f"API Error creating comment: {str(exc)}")
            raise HTTPException(status_code=500, detail="Internal server error") from exc

    return api
