from __future__ import annotations

from fastapi import APIRouter, Depends

from ai_podcast.dependencies import get_ai_podcast_service
from ai_podcast.schemas import (
    ArticlePodcastCreateRequest,
    ArticlePodcastCreateResponse,
    ArticlePodcastJobDetailResponse,
    ArticlePodcastJobListResponse,
)
from ai_podcast.service import AIPodcastService
from dependencies import get_optional_auth_user, resolve_user_id
from schemas import AuthenticatedUser

router = APIRouter(tags=["article-podcast"])


@router.post("/api/v1/article/podcast-jobs", status_code=202, response_model=ArticlePodcastCreateResponse)
async def create_article_podcast_job(
    request: ArticlePodcastCreateRequest,
    auth_user: AuthenticatedUser | None = Depends(get_optional_auth_user),
    service: AIPodcastService = Depends(get_ai_podcast_service),
):
    user_id = resolve_user_id(auth_user)
    return await service.create_job(owner_user_id=user_id, request=request)


@router.get("/api/v1/article/podcast-jobs", response_model=ArticlePodcastJobListResponse)
async def list_article_podcast_jobs(
    auth_user: AuthenticatedUser | None = Depends(get_optional_auth_user),
    service: AIPodcastService = Depends(get_ai_podcast_service),
):
    user_id = resolve_user_id(auth_user)
    return await service.list_jobs(owner_user_id=user_id)


@router.get("/api/v1/article/podcast-jobs/{job_id}", response_model=ArticlePodcastJobDetailResponse)
async def get_article_podcast_job(
    job_id: str,
    auth_user: AuthenticatedUser | None = Depends(get_optional_auth_user),
    service: AIPodcastService = Depends(get_ai_podcast_service),
):
    user_id = resolve_user_id(auth_user)
    return await service.get_job_detail(owner_user_id=user_id, job_id=job_id)
