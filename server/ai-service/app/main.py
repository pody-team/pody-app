from __future__ import annotations

from contextlib import asynccontextmanager
import json
from typing import Annotated
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.responses import StreamingResponse

from .config import Settings, load_settings
from .models import AddThreadMessageRequest, AuthContext, CreateThreadRequest, GeneratePlanRequest
from .planner import (
    PlannerError,
    build_create_agent,
    build_planner,
)
from .repository import AIRepository, NotFoundError, create_pool
from .service import AIService


def create_app(service: AIService | None = None, settings: Settings | None = None) -> FastAPI:
    resolved_settings = settings
    if resolved_settings is None and service is None:
        resolved_settings = load_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if service is not None:
            app.state.ai_service = service
            yield
            return

        if resolved_settings is None:
            raise RuntimeError("settings are required when no AI service instance is injected")

        pool = create_pool(resolved_settings.database_url)
        repository = AIRepository(pool)
        create_agent = build_create_agent(resolved_settings)
        planner = build_planner(resolved_settings)
        provider_name = "google-genai" if resolved_settings.use_google_provider else "stub"
        app.state.ai_service = AIService(
            repository,
            create_agent,
            planner,
            provider_name,
        )
        try:
            yield
        finally:
            pool.close()

    app = FastAPI(title="Pody AI Service", version="0.1.0", lifespan=lifespan)
    if service is not None:
        app.state.ai_service = service

    @app.exception_handler(NotFoundError)
    async def not_found_handler(_: Request, exc: NotFoundError):
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"error": str(exc)})

    @app.exception_handler(PlannerError)
    async def planner_error_handler(_: Request, exc: PlannerError):
        return JSONResponse(status_code=status.HTTP_502_BAD_GATEWAY, content={"error": str(exc)})

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    @app.get("/api/v1/ai/voice-profiles")
    def list_voice_profiles(
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        _ = auth
        return {"voice_profiles": ai_service.list_voice_profiles()}

    @app.post("/api/v1/ai/chat-create/threads", status_code=status.HTTP_201_CREATED)
    def create_thread(
        request: CreateThreadRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.create_thread(auth, request)}

    @app.get("/api/v1/ai/chat-create/threads/{thread_id}")
    def get_thread(
        thread_id: UUID,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.get_thread(auth, thread_id)}

    @app.post("/api/v1/ai/chat-create/threads/stream")
    def stream_create_thread(
        request: CreateThreadRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return StreamingResponse(
            _sse(ai_service.stream_create_thread(auth, request)),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    @app.post("/api/v1/ai/chat-create/threads/{thread_id}/messages")
    def add_thread_message(
        thread_id: UUID,
        request: AddThreadMessageRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.add_thread_message(auth, thread_id, request)}

    @app.post("/api/v1/ai/chat-create/threads/{thread_id}/messages/stream")
    def stream_add_thread_message(
        thread_id: UUID,
        request: AddThreadMessageRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return StreamingResponse(
            _sse(ai_service.stream_add_thread_message(auth, thread_id, request)),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    @app.post("/api/v1/ai/episode-plans/generate", status_code=status.HTTP_201_CREATED)
    def generate_episode_plan(
        request: GeneratePlanRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        plan, job = ai_service.generate_episode_plan(auth, request)
        return {"plan": plan, "job": job}

    @app.get("/api/v1/ai/jobs/{job_id}")
    def get_job(
        job_id: UUID,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"job": ai_service.get_job(auth, job_id)}

    return app


def get_service(request: Request) -> AIService:
    service = getattr(request.app.state, "ai_service", None)
    if service is None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="AI service is not initialized")
    return service


def require_auth(request: Request) -> AuthContext:
    user_id = (request.headers.get("X-Auth-User-ID") or "").strip()
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing auth user id")

    try:
        return AuthContext(
            user_id=user_id,
            email=(request.headers.get("X-Auth-Email") or "").strip() or None,
            name=(request.headers.get("X-Auth-Name") or "").strip() or None,
        )
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"invalid auth context: {exc}") from exc


def _sse(events):
    try:
        for item in events:
            event = str(item.get("event") or "message").strip() or "message"
            payload = item.get("data")
            yield _format_sse(event, payload)
    except Exception as exc:
        yield _format_sse("error", {"message": str(exc)})


def _format_sse(event: str, payload) -> str:
    body = json.dumps(payload or {}, ensure_ascii=False)
    return f"event: {event}\ndata: {body}\n\n"
