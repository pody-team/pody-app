from __future__ import annotations

import re

from ai_podcast.schemas import ScriptDraft, ValidationReport

WORDS_PER_MINUTE = 150
MIN_DURATION_RATIO = 0.85


def estimate_duration_seconds(*, word_count: int) -> int:
    return round((word_count / WORDS_PER_MINUTE) * 60) if word_count > 0 else 0


def minimum_word_count_for_target_minutes(target_minutes: int) -> int:
    target_seconds = max(60, target_minutes * 60)
    minimum_seconds = round(target_seconds * MIN_DURATION_RATIO)
    return max(1, round((minimum_seconds / 60) * WORDS_PER_MINUTE))


def validate_script(*, draft: ScriptDraft, target_minutes: int) -> ValidationReport:
    errors: list[str] = []
    warnings: list[str] = []
    script = (draft.script_text or "").strip()
    outline = draft.outline or []

    if not draft.podcast_title.strip():
        errors.append("podcast title is required")
    if not script:
        errors.append("script text is required")
    if not outline:
        errors.append("outline is required")

    word_count = len(re.findall(r"\w+", script, flags=re.UNICODE))
    estimated_duration_seconds = estimate_duration_seconds(word_count=word_count)
    target_seconds = max(60, target_minutes * 60)
    if estimated_duration_seconds < round(target_seconds * MIN_DURATION_RATIO):
        warnings.append("script may be shorter than target duration")

    normalized_script = re.sub(r"\s+", " ", script).strip().lower()
    if normalized_script:
        halfway = len(normalized_script) // 2
        if halfway and normalized_script[:halfway] == normalized_script[halfway : halfway * 2]:
            warnings.append("script appears repetitive")

    return ValidationReport(
        valid=not errors,
        errors=errors,
        warnings=warnings,
        estimated_duration_seconds=estimated_duration_seconds,
        word_count=word_count,
    )
