from __future__ import annotations

from ai_podcast.schemas import ResearchPack, SynthesisDraft


def build_synthesis(
    *,
    research_pack: ResearchPack,
    text_provider,
) -> SynthesisDraft:
    return text_provider.synthesize(payload=research_pack.model_dump(mode="json"))
