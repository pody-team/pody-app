from __future__ import annotations

import io
import wave

from app.show_creation import ScriptTurn
from app.transcript_generation import EpisodeTranscriptSource, SubprocessTranscriptGenerator


def _silent_wav_bytes(duration_seconds: int = 1, sample_rate: int = 24000) -> bytes:
    frame_count = duration_seconds * sample_rate
    pcm = b"\x00\x00" * frame_count
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm)
    return buffer.getvalue()


def test_subprocess_transcript_generator_returns_segments_in_proportional_mode() -> None:
    generator = SubprocessTranscriptGenerator(alignment_mode="proportional", timeout_seconds=60)
    artifact = generator.generate_transcript(
        EpisodeTranscriptSource(
            episode_id="ep-1",
            show_id="show-1",
            episode_slug="ep-1",
            language_code="vi",
            audio_bytes=_silent_wav_bytes(),
            turns=(
                ScriptTurn(speaker="Atlas", text="Mo dau ngan gon"),
                ScriptTurn(speaker="Mira", text="Noi dung tiep theo"),
            ),
        )
    )

    assert artifact.alignment_method == "proportional"
    assert len(artifact.segments) == 2
    assert artifact.segments[0].speaker == "Atlas"
    assert artifact.segments[1].speaker == "Mira"
