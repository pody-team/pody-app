from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from config.database import get_db_session
from repositories import (
    ArticleCommentRepository,
    ArticleMetricRepository,
    ArticleQueryRepository,
    ArticleReactionRepository,
    ArticleStatsRepository,
    ArticleWriteRepository,
)
from schemas import AuthenticatedUser
from services import ArticleEngagementService, ArticleQueryService


async def get_session_dependency():
    async with get_db_session() as session:
        yield session


async def get_article_query_service(
    session: AsyncSession = Depends(get_session_dependency),
) -> ArticleQueryService:
    return ArticleQueryService(
        write_repository=ArticleWriteRepository(session),
        query_repository=ArticleQueryRepository(session),
        stats_repository=ArticleStatsRepository(session),
        reaction_repository=ArticleReactionRepository(session),
        comment_repository=ArticleCommentRepository(session),
    )


async def get_article_engagement_service(
    session: AsyncSession = Depends(get_session_dependency),
) -> ArticleEngagementService:
    return ArticleEngagementService(
        write_repository=ArticleWriteRepository(session),
        reaction_repository=ArticleReactionRepository(session),
        metric_repository=ArticleMetricRepository(session),
        comment_repository=ArticleCommentRepository(session),
    )


def get_optional_auth_user(
    x_auth_user_id: Optional[str] = Header(default=None, alias="X-Auth-User-ID"),
    x_auth_email: Optional[str] = Header(default=None, alias="X-Auth-Email"),
    x_auth_name: Optional[str] = Header(default=None, alias="X-Auth-Name"),
) -> Optional[AuthenticatedUser]:
    raw_user_id = (x_auth_user_id or "").strip()
    if not raw_user_id:
        return None

    try:
        return AuthenticatedUser(
            user_id=raw_user_id,
            email=(x_auth_email or "").strip() or None,
            name=(x_auth_name or "").strip() or None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid auth user id") from exc


def resolve_user_id(auth_user: Optional[AuthenticatedUser], fallback_user_id: Optional[str]) -> str:
    if auth_user is not None:
        return auth_user.user_id
    if fallback_user_id is not None and fallback_user_id.strip():
        return fallback_user_id.strip()
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing auth user id")
