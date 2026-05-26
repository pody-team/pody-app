from __future__ import annotations

from app.model.request import KafkaMessageContext
from app.model.response import ArticleProcessingResult
from app.service.article_embedding_service import ArticleEmbeddingService


class ArticleEventController:
    """Controller nhan event bai bao da parse tu Kafka consumer."""

    def __init__(self, service: ArticleEmbeddingService) -> None:
        self._service = service

    def handle_message(self, payload: object, message: KafkaMessageContext) -> ArticleProcessingResult:
        """Chuyen payload Kafka sang service xu ly embedding bai bao."""
        return self._service.process_message(payload, message)
