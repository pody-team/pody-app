from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ai_podcast.repository import AIPodcastRepository
from ai_podcast.service import AIPodcastRuntime, AIPodcastService
from dependencies import get_session_dependency

_runtime: AIPodcastRuntime | None = None


def get_ai_podcast_runtime() -> AIPodcastRuntime:
    global _runtime
    if _runtime is None:
        _runtime = AIPodcastRuntime()
    return _runtime


async def initialize_ai_podcast_runtime() -> AIPodcastRuntime:
    runtime = get_ai_podcast_runtime()
    await runtime.start()
    return runtime


async def shutdown_ai_podcast_runtime() -> None:
    global _runtime
    if _runtime is not None:
        await _runtime.stop()


async def get_ai_podcast_service(
    session: AsyncSession = Depends(get_session_dependency),
) -> AIPodcastService:
    return AIPodcastService(AIPodcastRepository(session), get_ai_podcast_runtime())
