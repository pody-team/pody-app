from __future__ import annotations

import re

from ai_podcast.schemas import ResearchPack, ScriptDraft, SynthesisDraft
from ai_podcast.pipeline.validator import minimum_word_count_for_target_minutes


def build_script(
    *,
    research_pack: ResearchPack,
    synthesis: SynthesisDraft,
    text_provider,
    target_minutes: int,
    language_code: str,
    attempt_feedback: str | None = None,
) -> ScriptDraft:
    return text_provider.write_script(
        payload={
            "research_pack": research_pack.model_dump(mode="json"),
            "synthesis": synthesis.model_dump(mode="json"),
            "target_minutes": target_minutes,
            "target_duration_seconds": target_minutes * 60,
            "minimum_words": minimum_word_count_for_target_minutes(target_minutes),
            "article_count": len(research_pack.primary_sources),
            "attempt_feedback": attempt_feedback,
            "language_code": language_code,
        }
    )


def expand_script_to_target(
    *,
    draft: ScriptDraft,
    synthesis: SynthesisDraft,
    target_minutes: int,
) -> ScriptDraft:
    minimum_words = minimum_word_count_for_target_minutes(target_minutes)
    current_script = (draft.script_text or "").strip()
    current_word_count = len(re.findall(r"\w+", current_script, flags=re.UNICODE))
    if current_word_count >= minimum_words:
        return draft

    topic = (synthesis.topic or "cum bai bao nay").strip() or "cum bai bao nay"
    expansion_pool = [
        *[
            f"Dao sau hon o y {index + 1}, {item}. Khi dat vao toan canh cua chu de {topic}, chi tiet nay cho thay nguyen nhan, tac dong, va nhung dieu nguoi nghe nen tiep tuc quan sat trong thoi gian toi."
            for index, item in enumerate(synthesis.key_insights or [])
            if str(item).strip()
        ],
        *[
            f"Mot diem lien ket quan trong la {item}. Day la nut giao giua nhieu bai viet, giup nguoi nghe thay duoc cach cac su kien va xu huong dang bo sung y nghia cho nhau."
            for item in (synthesis.overlap_points or [])
            if str(item).strip()
        ],
        *[
            f"Mo rong boi canh, {item}. Thong tin nay giup ban tin khong chi dung o muc cap nhat su kien, ma con giai thich vi sao dien bien nay dang duoc chu y va co the anh huong den buc tranh rong hon."
            for item in (synthesis.external_context or [])
            if str(item).strip()
        ],
    ]

    if not expansion_pool:
        expansion_pool = [
            f"Nhìn rộng hơn, chu de {topic} dang tao ra nhieu thay doi lien tiep. Vi the, viec nhin cac bai bao theo cum se giup nguoi nghe hieu ro hon boi canh, muc do anh huong, va nhung chi dau moi can duoc theo doi tiep."
        ]

    expanded_parts = [current_script] if current_script else []
    pool_index = 0
    while len(re.findall(r"\w+", " ".join(expanded_parts), flags=re.UNICODE)) < minimum_words:
        expanded_parts.append(expansion_pool[pool_index % len(expansion_pool)])
        pool_index += 1

    return ScriptDraft(
        podcast_title=draft.podcast_title,
        podcast_description=draft.podcast_description,
        outline=draft.outline,
        script_text=" ".join(part for part in expanded_parts if part).strip(),
    )
