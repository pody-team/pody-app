from __future__ import annotations

from typing import TYPE_CHECKING

from app.model.response import HealthResponse, ServiceOverviewResponse

if TYPE_CHECKING:
    from app.runtime import EmbeddingRuntime


class SystemController:
    def __init__(self, runtime: EmbeddingRuntime) -> None:
        self._runtime = runtime

    def get_service_overview(self) -> ServiceOverviewResponse:
        return self._runtime.service_overview()

    def get_health(self) -> HealthResponse:
        return self._runtime.health()
