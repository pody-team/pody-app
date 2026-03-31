from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class TranscriptWord:
    start_seconds: float
    end_seconds: float
    text: str


@dataclass(frozen=True)
class TranscriptSegment:
    start_seconds: float
    end_seconds: float
    text: str
    speaker: str | None = None
    words: tuple[TranscriptWord, ...] = ()


@dataclass(frozen=True)
class TranscriptArtifact:
    text: str
    language: str
    duration_seconds: float
    alignment_method: str
    segments: tuple[TranscriptSegment, ...]
    raw_json: str


@dataclass(frozen=True)
class EpisodeTranscriptSource:
    episode_id: str
    show_id: str
    episode_slug: str
    language_code: str
    audio_bytes: bytes
    turns: tuple[Any, ...]


class TranscriptGenerationError(Exception):
    pass


class SubprocessTranscriptGenerator:
    def __init__(
        self,
        *,
        alignment_mode: str = "auto",
        timeout_seconds: int = 900,
        script_path: str | None = None,
    ) -> None:
        self._alignment_mode = alignment_mode.strip().lower() or "auto"
        self._timeout_seconds = max(30, timeout_seconds)
        self._script_path = Path(script_path) if script_path else Path(__file__).with_name("align.py")

    @property
    def enabled(self) -> bool:
        return self._script_path.exists()

    def generate_transcript(self, source: EpisodeTranscriptSource) -> TranscriptArtifact:
        if not self.enabled:
            raise TranscriptGenerationError(f"alignment script not found at {self._script_path}")
        if not source.audio_bytes:
            raise TranscriptGenerationError("audio bytes are required for transcript generation")
        if not source.turns:
            raise TranscriptGenerationError("dialogue turns are required for transcript generation")

        with tempfile.TemporaryDirectory(prefix="pody-transcript-") as tempdir:
            temp_path = Path(tempdir)
            audio_path = temp_path / "audio.wav"
            dialogue_path = temp_path / "episode.json"
            output_path = temp_path / "transcript.json"
            audio_path.write_bytes(source.audio_bytes)
            dialogue_path.write_text(
                json.dumps(
                    {
                        "dialogue": [
                            {
                                "speaker": turn.speaker,
                                "text": turn.text,
                                **({"emotion": turn.emotion} if turn.emotion else {}),
                                **({"direction": turn.direction} if turn.direction else {}),
                            }
                            for turn in source.turns
                        ]
                    },
                    ensure_ascii=False,
                    indent=2,
                ),
                encoding="utf-8",
            )

            env = os.environ.copy()
            env["ALIGN_MODE"] = self._alignment_mode
            process = subprocess.run(
                [sys.executable, str(self._script_path), str(audio_path), str(dialogue_path), str(output_path)],
                capture_output=True,
                text=True,
                timeout=self._timeout_seconds,
                env=env,
            )
            if process.returncode != 0:
                stderr = (process.stderr or "").strip()
                stdout = (process.stdout or "").strip()
                if process.returncode < 0:
                    signal_number = abs(process.returncode)
                    detail_parts = [
                        f"alignment process terminated by signal {signal_number} (likely killed by the OS due to memory pressure)"
                    ]
                    if stdout:
                        detail_parts.append(f"stdout: {stdout}")
                    if stderr:
                        detail_parts.append(f"stderr: {stderr}")
                    detail = " | ".join(detail_parts)
                else:
                    detail = stderr or stdout or f"exit code {process.returncode}"
                raise TranscriptGenerationError(detail)
            if not output_path.exists():
                raise TranscriptGenerationError("alignment finished without transcript output")

            payload = json.loads(output_path.read_text(encoding="utf-8"))
            raw_json = json.dumps(payload, ensure_ascii=False, indent=2)
            segments = []
            for item in payload.get("segments", []):
                words = tuple(
                    TranscriptWord(
                        start_seconds=float(word.get("start", 0.0)),
                        end_seconds=float(word.get("end", 0.0)),
                        text=str(word.get("text") or ""),
                    )
                    for word in item.get("words", []) or []
                )
                segments.append(
                    TranscriptSegment(
                        start_seconds=float(item.get("start", 0.0)),
                        end_seconds=float(item.get("end", 0.0)),
                        text=str(item.get("text") or ""),
                        speaker=str(item.get("speaker") or "") or None,
                        words=words,
                    )
                )
            return TranscriptArtifact(
                text=str(payload.get("text") or ""),
                language=str(payload.get("language") or source.language_code or "vi"),
                duration_seconds=float(payload.get("duration") or 0.0),
                alignment_method=str(payload.get("alignment_method") or "unknown"),
                segments=tuple(segments),
                raw_json=raw_json,
            )
