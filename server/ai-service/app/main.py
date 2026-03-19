from __future__ import annotations

from contextlib import asynccontextmanager
import json
from typing import Annotated
from uuid import UUID

import yaml
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response, Security, status
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.openapi.utils import get_openapi
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.security import APIKeyHeader

from .config import Settings, load_settings
from .models import (
    AddThreadMessageRequest,
    AuthContext,
    ChatThreadListResponse,
    ChatThreadResponse,
    CreateThreadRequest,
    GeneratePlanRequest,
    GeneratePlanResponse,
    GenerationJobResponse,
    HealthResponse,
    ProductionPlanResponse,
    ProductionPlansResponse,
    VoiceProfilesResponse,
)
from .planner import (
    PlannerError,
    build_create_agent,
    build_planner,
)
from .repository import AIRepository, NotFoundError, create_pool
from .service import AIService

PUBLIC_AI_OPENAPI_URL = "/api/v1/public/ai/openapi.yaml"
auth_user_id_header = APIKeyHeader(name="X-Auth-User-ID", auto_error=False)
openapi_tags = [
    {"name": "Health", "description": "Health and availability endpoints."},
    {"name": "Docs", "description": "OpenAPI and Swagger UI entry points."},
    {"name": "Catalog", "description": "Voice profile catalog endpoints used by creators."},
    {"name": "Chat Create", "description": "Iterative AI chat endpoints that build production plans."},
    {"name": "Production Plans", "description": "Persisted plan history and generation endpoints."},
    {"name": "Jobs", "description": "Background generation job status endpoints."},
]


def _is_null_schema(node: object) -> bool:
    return isinstance(node, dict) and node.get("type") == "null"


def _normalize_openapi_3_0(node: object) -> object:
    if isinstance(node, list):
        return [_normalize_openapi_3_0(item) for item in node]

    if not isinstance(node, dict):
        return node

    normalized = {key: _normalize_openapi_3_0(value) for key, value in node.items()}
    any_of = normalized.get("anyOf")
    if isinstance(any_of, list):
        non_null = [item for item in any_of if not _is_null_schema(item)]
        null_items = [item for item in any_of if _is_null_schema(item)]
        if len(non_null) == 1 and len(null_items) == 1 and isinstance(non_null[0], dict):
            merged = dict(non_null[0])
            for key, value in normalized.items():
                if key == "anyOf":
                    continue
                merged[key] = value
            merged["nullable"] = True
            return merged

    return normalized


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

    app = FastAPI(
        title="Pody AI Service API",
        version="1.0.0",
        description="Creator-side AI planning and drafting APIs for Pody.",
        lifespan=lifespan,
        openapi_tags=openapi_tags,
    )
    if service is not None:
        app.state.ai_service = service

    def custom_openapi():
        if app.openapi_schema:
            return app.openapi_schema

        openapi_schema = get_openapi(
            title=app.title,
            version=app.version,
            description=app.description,
            routes=app.routes,
            tags=app.openapi_tags,
        )
        openapi_schema = _normalize_openapi_3_0(openapi_schema)
        openapi_schema.get("paths", {}).pop("/healthz", None)
        openapi_schema["openapi"] = "3.0.3"
        openapi_schema["servers"] = [{"url": "http://localhost:8080"}]
        app.openapi_schema = openapi_schema
        return app.openapi_schema

    app.openapi = custom_openapi

    @app.exception_handler(NotFoundError)
    async def not_found_handler(_: Request, exc: NotFoundError):
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"error": str(exc)})

    @app.exception_handler(PlannerError)
    async def planner_error_handler(_: Request, exc: PlannerError):
        return JSONResponse(status_code=status.HTTP_502_BAD_GATEWAY, content={"error": str(exc)})

    @app.get("/healthz", tags=["Health"], summary="Service health check", response_model=HealthResponse)
    def healthz():
        return {"status": "ok"}

    @app.get("/api/v1/public/ai/healthz", tags=["Health"], summary="Public AI health check", response_model=HealthResponse)
    def public_healthz():
        return {"status": "ok"}

    @app.get(
        PUBLIC_AI_OPENAPI_URL,
        tags=["Docs"],
        summary="Download AI OpenAPI spec",
        operation_id="getAIOpenAPI",
        response_class=Response,
    )
    def public_openapi():
        return Response(
            content=yaml.safe_dump(app.openapi(), sort_keys=False, allow_unicode=True),
            media_type="application/yaml",
        )

    @app.get(
        "/api/v1/public/ai/docs",
        tags=["Docs"],
        summary="Swagger UI for AI service",
        operation_id="getAISwaggerUI",
        response_class=HTMLResponse,
    )
    def public_docs():
        return get_swagger_ui_html(openapi_url=PUBLIC_AI_OPENAPI_URL, title="Pody AI Service Docs")

    @app.get(
        "/api/v1/ai/voice-profiles",
        tags=["Catalog"],
        summary="List available AI voice profiles",
        response_model=VoiceProfilesResponse,
    )
    def list_voice_profiles(
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        _ = auth
        return {"voice_profiles": ai_service.list_voice_profiles()}

    @app.post(
        "/api/v1/ai/chat-create/threads",
        status_code=status.HTTP_201_CREATED,
        tags=["Chat Create"],
        summary="Create a new AI chat thread and initial production plan",
        response_model=ChatThreadResponse,
    )
    def create_thread(
        request: CreateThreadRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.create_thread(auth, request)}

    @app.get(
        "/api/v1/ai/chat-create/threads",
        tags=["Chat Create"],
        summary="List AI chat threads for the current creator",
        response_model=ChatThreadListResponse,
    )
    def list_threads(
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
        limit: Annotated[int, Query(description="Requested number of threads to return; the service clamps values to 1..100.")] = 30,
    ):
        normalized_limit = max(1, min(limit, 100))
        return {"threads": ai_service.list_threads(auth, normalized_limit)}

    @app.get(
        "/api/v1/ai/chat-create/threads/{thread_id}",
        tags=["Chat Create"],
        summary="Get one AI chat thread with messages and current plan",
        response_model=ChatThreadResponse,
    )
    def get_thread(
        thread_id: UUID,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.get_thread(auth, thread_id)}

    @app.get(
        "/api/v1/ai/production-plans",
        tags=["Production Plans"],
        summary="List saved production plans for the current creator",
        response_model=ProductionPlansResponse,
    )
    def list_drafts(
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
        limit: Annotated[int, Query(description="Requested number of plans to return; the service clamps values to 1..100.")] = 50,
    ):
        normalized_limit = max(1, min(limit, 100))
        return {"drafts": ai_service.list_drafts(auth, normalized_limit)}

    @app.get(
        "/api/v1/ai/production-plans/{plan_id}",
        tags=["Production Plans"],
        summary="Get one saved production plan",
        response_model=ProductionPlanResponse,
    )
    def get_draft(
        plan_id: UUID,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"draft": ai_service.get_draft(auth, plan_id)}

    @app.post(
        "/api/v1/ai/chat-create/threads/stream",
        tags=["Chat Create"],
        summary="Create a thread and stream AI planning events",
        responses={
            200: {
                "description": "Server-sent events stream with status, deltas, thread payload, and done event.",
                "content": {"text/event-stream": {"schema": {"type": "string"}}},
            }
        },
    )
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

    @app.post(
        "/api/v1/ai/chat-create/threads/{thread_id}/messages",
        tags=["Chat Create"],
        summary="Append a message to an existing AI chat thread",
        response_model=ChatThreadResponse,
    )
    def add_thread_message(
        thread_id: UUID,
        request: AddThreadMessageRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        return {"thread": ai_service.add_thread_message(auth, thread_id, request)}

    @app.post(
        "/api/v1/ai/chat-create/threads/{thread_id}/messages/stream",
        tags=["Chat Create"],
        summary="Append a message and stream AI planning updates",
        responses={
            200: {
                "description": "Server-sent events stream with status updates, thread payload, and done event.",
                "content": {"text/event-stream": {"schema": {"type": "string"}}},
            }
        },
    )
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

    @app.post(
        "/api/v1/ai/episode-plans/generate",
        status_code=status.HTTP_201_CREATED,
        tags=["Production Plans"],
        summary="Generate a production plan and job record from a prompt",
        response_model=GeneratePlanResponse,
    )
    def generate_episode_plan(
        request: GeneratePlanRequest,
        auth: Annotated[AuthContext, Depends(require_auth)],
        ai_service: Annotated[AIService, Depends(get_service)],
    ):
        plan, job = ai_service.generate_episode_plan(auth, request)
        return {"plan": plan, "job": job}

    @app.get(
        "/api/v1/ai/jobs/{job_id}",
        tags=["Jobs"],
        summary="Get the status of a generation job",
        response_model=GenerationJobResponse,
    )
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


def require_auth(
    x_auth_user_id: Annotated[str | None, Security(auth_user_id_header)],
    x_auth_email: Annotated[str | None, Header(alias="X-Auth-Email")] = None,
    x_auth_name: Annotated[str | None, Header(alias="X-Auth-Name")] = None,
) -> AuthContext:
    user_id = (x_auth_user_id or "").strip()
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing auth user id")

    try:
        return AuthContext(
            user_id=user_id,
            email=(x_auth_email or "").strip() or None,
            name=(x_auth_name or "").strip() or None,
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
