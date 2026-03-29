from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
import uvicorn

from app.api.routes import build_router
from app.config import AppSettings, configure_logging, load_settings
from app.runtime import EmbeddingRuntime
from app.view import ArticleSearchView, SystemView


def create_app(
    runtime: EmbeddingRuntime | None = None,
    settings: AppSettings | None = None,
) -> FastAPI:
    resolved_settings = settings or (runtime.settings if runtime is not None else load_settings())
    logger = configure_logging(resolved_settings.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        active_runtime = runtime or EmbeddingRuntime(resolved_settings, logger)
        app.state.runtime = active_runtime
        app.state.article_search_controller = active_runtime.article_search_controller
        app.state.article_search_view = ArticleSearchView()
        app.state.system_controller = active_runtime.system_controller
        app.state.system_view = SystemView()
        logger.info(
            "Starting embedding service on port %s for topic %s",
            resolved_settings.port,
            resolved_settings.kafka.topic,
        )
        active_runtime.start()
        try:
            yield
        finally:
            active_runtime.stop()
            logger.info("Embedding service stopped")

    app = FastAPI(
        title="Pody Embedding Service",
        version="1.0.0",
        description="Article embedding pipeline powered by Kafka, Debezium, PostgreSQL, and Gemini embeddings.",
        lifespan=lifespan,
    )
    app.include_router(build_router())
    return app


if __name__ == "__main__":
    settings = load_settings()
    uvicorn.run(
        "app.main:create_app",
        factory=True,
        host="0.0.0.0",
        port=settings.port,
    )
