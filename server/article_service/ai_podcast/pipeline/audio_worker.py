from __future__ import annotations

from ai_podcast.providers.tts_generation import AudioArtifact
from ai_podcast.schemas import ScriptDraft


def synthesize_audio(
    *,
    draft: ScriptDraft,
    voice: str | None,
    language_code: str,
    tts_provider,
) -> AudioArtifact:
    return tts_provider.synthesize(
        script_text=draft.script_text,
        voice=voice,
        language_code=language_code,
    )
