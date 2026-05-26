from __future__ import annotations

from app.model.value_object import PreparedArticleChunk
from app.util.hashing import sha256_text


def build_article_chunks(
    *,
    title: str,
    summary: str | None,
    content: str | None,
    target_chars: int,
    overlap_chars: int,
    min_chunk_chars: int,
) -> list[PreparedArticleChunk]:
    """Tach title/summary/content thanh cac chunk co metadata de embed."""
    chunks: list[PreparedArticleChunk] = []
    chunk_index = 0

    normalized_title = _normalize_text(title)
    if normalized_title:
        chunks.append(_build_chunk(chunk_index, "title", normalized_title))
        chunk_index += 1

    normalized_summary = _normalize_text(summary or "")
    if normalized_summary and normalized_summary != normalized_title:
        chunks.append(_build_chunk(chunk_index, "summary", normalized_summary))
        chunk_index += 1

    normalized_body = _normalize_text(content or "")
    for piece in _split_body(
        text=normalized_body,
        target_chars=target_chars,
        overlap_chars=overlap_chars,
        min_chunk_chars=min_chunk_chars,
    ):
        chunks.append(_build_chunk(chunk_index, "body", piece))
        chunk_index += 1

    if not chunks and normalized_title:
        chunks.append(_build_chunk(0, "title", normalized_title))

    return chunks


def _split_body(
    *,
    text: str,
    target_chars: int,
    overlap_chars: int,
    min_chunk_chars: int,
) -> list[str]:
    """Cat noi dung body thanh cac doan gan target_chars va co overlap."""
    if not text:
        return []
    if len(text) <= target_chars:
        return [text]

    pieces: list[str] = []
    start = 0
    text_length = len(text)

    while start < text_length:
        preferred_end = min(start + target_chars, text_length)
        end = _find_split_position(text, start, preferred_end, min_chunk_chars)
        segment = text[start:end].strip()
        if segment:
            pieces.append(segment)
        if end >= text_length:
            break
        start = max(end - overlap_chars, start + 1)

    return pieces


def _find_split_position(text: str, start: int, preferred_end: int, min_chunk_chars: int) -> int:
    """Tim vi tri cat tu nhien theo cau/doan, fallback ve khoang trang."""
    if preferred_end >= len(text):
        return len(text)

    window_start = min(len(text), start + min_chunk_chars)
    for delimiter in ("\n\n", ". ", "! ", "? ", "; ", ", "):
        index = text.rfind(delimiter, window_start, preferred_end)
        if index != -1:
            return index + len(delimiter.strip())

    fallback = text.rfind(" ", window_start, preferred_end)
    if fallback != -1:
        return fallback
    return preferred_end


def _build_chunk(chunk_index: int, chunk_type: str, content: str) -> PreparedArticleChunk:
    """Tao value object chunk kem hash va uoc luong token."""
    normalized = content.strip()
    return PreparedArticleChunk(
        chunk_index=chunk_index,
        chunk_type=chunk_type,
        content=normalized,
        token_count_estimate=max(1, len(normalized) // 4),
        char_count=len(normalized),
        content_hash=sha256_text(normalized),
    )


def _normalize_text(value: str) -> str:
    """Chuan hoa newline va bo dong rong truoc khi chunking."""
    lines = [line.strip() for line in value.replace("\r\n", "\n").split("\n")]
    filtered_lines = [line for line in lines if line]
    return "\n".join(filtered_lines).strip()
