from __future__ import annotations

import io
import wave
from dataclasses import dataclass
from typing import Any

from ai_podcast.config import AIPodcastSettings
from ai_podcast.prompts.templates import TTS_STYLE_PROMPT
from ai_podcast.providers.genai_client import build_genai_client

try:
    from google.genai import types
except ImportError:  # pragma: no cover - optional dependency in tests
    types = None


@dataclass(frozen=True)
class AudioArtifact:
    audio_bytes: bytes
    duration_seconds: int
    transcript_json: str
    mime_type: str = "audio/wav"


class TTSGenerationProvider:
    def synthesize(self, *, script_text: str, voice: str | None, language_code: str) -> AudioArtifact:
        raise NotImplementedError


class StubTTSGenerationProvider(TTSGenerationProvider):
    def synthesize(self, *, script_text: str, voice: str | None, language_code: str) -> AudioArtifact:
        _ = voice
        _ = language_code
        payload = _pcm16_to_wav(b"\x00" * 48000)
        word_count = max(1, len(script_text.split()))
        duration_seconds = max(1, round((word_count / 150.0) * 60))
        return AudioArtifact(
            audio_bytes=payload,
            duration_seconds=duration_seconds,
            transcript_json='{"segments":[]}',
        )


class GoogleGenAITTSGenerationProvider(TTSGenerationProvider):
    def __init__(self, settings: AIPodcastSettings) -> None:
        self._client = build_genai_client(
            project=settings.google_cloud_project,
            location=settings.google_cloud_location,
        )
        self._model = settings.google_tts_model

    def synthesize(self, *, script_text: str, voice: str | None, language_code: str) -> AudioArtifact:
        if self._client is None or types is None:
            return StubTTSGenerationProvider().synthesize(
                script_text=script_text,
                voice=voice,
                language_code=language_code,
            )
        response = self._client.models.generate_content(
            model=self._model,
            contents=f"{TTS_STYLE_PROMPT}{script_text.strip()}",
            config=types.GenerateContentConfig(
                response_modalities=[types.Modality.AUDIO],
                speech_config=_build_speech_config(voice=voice, language_code=language_code),
            ),
        )
        pcm_bytes = _extract_audio_bytes(response)
        if not pcm_bytes:
            return StubTTSGenerationProvider().synthesize(
                script_text=script_text,
                voice=voice,
                language_code=language_code,
            )
        wav_bytes = _pcm16_to_wav(pcm_bytes)
        duration_seconds = max(1, len(pcm_bytes) // (24000 * 2))
        return AudioArtifact(
            audio_bytes=wav_bytes,
            duration_seconds=duration_seconds,
            transcript_json='{"segments":[]}',
        )


def build_tts_generation_provider(settings: AIPodcastSettings) -> TTSGenerationProvider:
    if settings.use_google_provider:
        return GoogleGenAITTSGenerationProvider(settings)
    return StubTTSGenerationProvider()


def _build_speech_config(*, voice: str | None, language_code: str):
    voice_name = _resolve_voice_name(voice)
    resolved_language = "vi-VN" if (language_code or "").strip().lower() == "vi" else (language_code or "vi-VN")
    return types.SpeechConfig(
        language_code=resolved_language,
        voice_config=types.VoiceConfig(
            prebuilt_voice_config=types.PrebuiltVoiceConfig(
                voice_name=voice_name,
            )
        ),
    )


def _resolve_voice_name(voice: str | None) -> str:
    normalized = (voice or "").strip().lower()
    mapping = {
        "kore": "Kore",
        "puck": "Puck",
        "charon": "Charon",
        "sulafat": "Sulafat",
        "zephyr": "Zephyr",
        "fenrir": "Fenrir",
        "aoede": "Aoede",
    }
    return mapping.get(normalized, "Kore")


def _extract_audio_bytes(response: Any) -> bytes:
    direct_bytes = getattr(response, "data", None)
    if isinstance(direct_bytes, bytes) and direct_bytes:
        return direct_bytes
    candidates = getattr(response, "candidates", None) or []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        parts = getattr(content, "parts", None) or []
        for part in parts:
            inline_data = getattr(part, "inline_data", None)
            data = getattr(inline_data, "data", None)
            if isinstance(data, bytes) and data:
                return data
    return b""


def _pcm16_to_wav(pcm_bytes: bytes, *, sample_rate: int = 24000, channels: int = 1, sample_width: int = 2) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(sample_width)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm_bytes)
    return buffer.getvalue()
