from __future__ import annotations

from fastapi.responses import JSONResponse

from app.model.response import HealthResponse, ServiceOverviewResponse


class SystemView:
    """View render response he thong va health check."""

    def render_service_overview(self, response: ServiceOverviewResponse) -> dict[str, object]:
        """Render thong tin tong quan service."""
        return response.to_dict()

    def render_health(self, response: HealthResponse) -> JSONResponse:
        """Render health va dung status 503 khi service chua san sang day du."""
        return JSONResponse(
            status_code=200 if response.status == "ok" else 503,
            content=response.to_dict(),
        )
