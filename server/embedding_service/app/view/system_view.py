from __future__ import annotations

from fastapi.responses import JSONResponse

from app.model.response import HealthResponse, ServiceOverviewResponse


class SystemView:
    def render_service_overview(self, response: ServiceOverviewResponse) -> dict[str, object]:
        return response.to_dict()

    def render_health(self, response: HealthResponse) -> JSONResponse:
        return JSONResponse(
            status_code=200 if response.status == "ok" else 503,
            content=response.to_dict(),
        )
