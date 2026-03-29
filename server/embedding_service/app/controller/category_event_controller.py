from __future__ import annotations

from app.model.request import KafkaMessageContext
from app.model.response.category_processing import CategoryProcessingResult
from app.service.category_embedding_service import CategoryEmbeddingService


class CategoryEventController:
    def __init__(self, service: CategoryEmbeddingService) -> None:
        self._service = service

    def handle_message(self, payload: object, message: KafkaMessageContext) -> CategoryProcessingResult:
        return self._service.process_message(payload, message)
