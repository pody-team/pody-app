from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, Request

from app.controller import ArticleSearchController, SystemController
from app.model.request import InvalidArticleSearchRequestError, parse_article_search_request
from app.view import ArticleSearchView, SystemView


def build_router() -> APIRouter:
    router = APIRouter()

    @router.get("/")
    def root(request: Request):
        controller: SystemController = request.app.state.system_controller
        view: SystemView = request.app.state.system_view
        return view.render_service_overview(controller.get_service_overview())

    @router.get("/healthz")
    def healthz(request: Request):
        controller: SystemController = request.app.state.system_controller
        view: SystemView = request.app.state.system_view
        return view.render_health(controller.get_health())

    @router.get("/api/v1/public/embedding/healthz")
    def public_healthz(request: Request):
        controller: SystemController = request.app.state.system_controller
        view: SystemView = request.app.state.system_view
        return view.render_health(controller.get_health())

    @router.post("/api/v1/public/embedding/articles/search")
    async def search_articles(request: Request):
        controller: ArticleSearchController = request.app.state.article_search_controller
        view: ArticleSearchView = request.app.state.article_search_view

        try:
            payload = await request.json()
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=400, detail="Request body must be valid JSON") from exc

        try:
            search_request = parse_article_search_request(payload)
        except InvalidArticleSearchRequestError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

        try:
            return view.render_search_results(controller.search_articles(search_request))
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    return router
