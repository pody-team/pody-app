from __future__ import annotations

from ai_podcast.schemas import ResearchPack, ScriptDraft, SynthesisDraft


def build_script(
    *,
    research_pack: ResearchPack,
    synthesis: SynthesisDraft,
    text_provider,
    target_minutes: int,
    language_code: str,
) -> ScriptDraft:
    return text_provider.write_script(
        payload={
            "research_pack": research_pack.model_dump(mode="json"),
            "synthesis": synthesis.model_dump(mode="json"),
            "target_minutes": target_minutes,
            "language_code": language_code,
        }
    )
