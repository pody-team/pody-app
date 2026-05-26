from __future__ import annotations

from math import sqrt

from app.model.value_object import PreparedArticleChunk


def build_weighted_document_embedding(
    chunks: list[PreparedArticleChunk],
    embeddings: list[list[float]],
) -> list[float]:
    """Tao vector document bang trung binh co trong so cua cac chunk embedding."""
    if not chunks or not embeddings:
        raise ValueError("chunks and embeddings are required")
    if len(chunks) != len(embeddings):
        raise ValueError("chunks and embeddings must have the same length")

    dimensions = len(embeddings[0])
    if dimensions == 0:
        raise ValueError("embedding vectors cannot be empty")

    accumulator = [0.0] * dimensions
    total_weight = 0.0

    for chunk, embedding in zip(chunks, embeddings, strict=True):
        if len(embedding) != dimensions:
            raise ValueError("all embeddings must use the same dimensions")
        weight = _chunk_weight(chunk)
        total_weight += weight
        for index, value in enumerate(embedding):
            accumulator[index] += float(value) * weight

    averaged = [value / total_weight for value in accumulator]
    magnitude = sqrt(sum(value * value for value in averaged))
    if magnitude == 0:
        return averaged
    return [value / magnitude for value in averaged]


def _chunk_weight(chunk: PreparedArticleChunk) -> float:
    """Tinh trong so chunk, uu tien title va summary hon body."""
    content_weight = max(float(chunk.token_count_estimate), float(chunk.char_count) / 4.0, 1.0)
    if chunk.chunk_type == "title":
        return content_weight * 1.35
    if chunk.chunk_type == "summary":
        return content_weight * 1.15
    return content_weight
