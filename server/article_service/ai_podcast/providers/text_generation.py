from __future__ import annotations

import json
from typing import Any

from ai_podcast.config import AIPodcastSettings
from ai_podcast.prompts.templates import RESEARCH_SUMMARY_PROMPT, SCRIPT_WRITER_PROMPT
from ai_podcast.providers.genai_client import build_genai_client
from ai_podcast.schemas import ScriptDraft, SynthesisDraft


class TextGenerationProvider:
    def synthesize(self, *, payload: dict[str, Any]) -> SynthesisDraft:
        raise NotImplementedError

    def write_script(self, *, payload: dict[str, Any]) -> ScriptDraft:
        raise NotImplementedError


class StubTextGenerationProvider(TextGenerationProvider):
    def synthesize(self, *, payload: dict[str, Any]) -> SynthesisDraft:
        sources = payload.get("primary_sources") or []
        titles = [str(item.get("title") or "").strip() for item in sources if str(item.get("title") or "").strip()]
        topic = titles[0] if titles else "Tin tuc duoc chon"
        research_summary = (
            "Tong hop nhanh cac bai bao duoc chon va boi canh lien quan de tao mot podcast ngan, mach lac."
        )
        return SynthesisDraft(
            topic=topic,
            key_insights=titles[:6] or ["Tong hop cac y chinh tu nhieu bai bao"],
            overlap_points=["Cac bai bao cung xoay quanh mot mach chu de lon"],
            external_context=[str(item.get("title") or "").strip() for item in payload.get("external_context_sources") or []][:3],
            research_summary=research_summary,
        )

    def write_script(self, *, payload: dict[str, Any]) -> ScriptDraft:
        synthesis = payload.get("synthesis") or {}
        topic = str(synthesis.get("topic") or "Tin tuc hom nay").strip() or "Tin tuc hom nay"
        key_insights = synthesis.get("key_insights") or ["Nhung dien bien dang chu y"]
        outline = [
            "Mo dau va dat van de",
            "Tong hop cac y chinh tu nhom bai bao",
            "Mo rong boi canh va diem dang theo doi",
            "Ket lai va nhan manh dieu can nho",
        ]
        body_parts = [
            f"Xin chao, day la ban tin audio ve chu de {topic}.",
            "Trong nhom bai bao ma ban vua chon, co mot so y chinh noi bat can luu y.",
        ]
        for insight in key_insights[:5]:
            body_parts.append(str(insight).strip())
        body_parts.append("Ben canh do, co mot vai thong tin mo rong giup dat cac bai viet vao boi canh rong hon.")
        for item in (synthesis.get("external_context") or [])[:3]:
            body_parts.append(str(item).strip())
        body_parts.append("Do la nhung diem noi bat nhat trong cum bai bao nay.")
        return ScriptDraft(
            podcast_title=f"Podcast bao chi: {topic}",
            podcast_description=f"Ban tom tat audio ve {topic}.",
            outline=outline,
            script_text=" ".join(part for part in body_parts if part),
        )


class GoogleGenAITextGenerationProvider(TextGenerationProvider):
    def __init__(self, settings: AIPodcastSettings) -> None:
        api_key = settings.google_api_key or "proxy-placeholder"
        self._client = build_genai_client(api_key=api_key, base_url=settings.google_base_url)
        self._model = settings.google_model

    def synthesize(self, *, payload: dict[str, Any]) -> SynthesisDraft:
        if self._client is None:
            return StubTextGenerationProvider().synthesize(payload=payload)
        prompt = f"{RESEARCH_SUMMARY_PROMPT}\n\nDu lieu:\n{json.dumps(payload, ensure_ascii=False)}"
        response = self._client.models.generate_content(model=self._model, contents=prompt)
        return _parse_json_response(response.text or "", SynthesisDraft, StubTextGenerationProvider().synthesize(payload=payload))

    def write_script(self, *, payload: dict[str, Any]) -> ScriptDraft:
        if self._client is None:
            return StubTextGenerationProvider().write_script(payload=payload)
        prompt = f"{SCRIPT_WRITER_PROMPT}\n\nDu lieu:\n{json.dumps(payload, ensure_ascii=False)}"
        response = self._client.models.generate_content(model=self._model, contents=prompt)
        return _parse_json_response(response.text or "", ScriptDraft, StubTextGenerationProvider().write_script(payload=payload))


def _parse_json_response(text: str, model_class: Any, fallback: Any) -> Any:
    try:
        start = text.index("{")
        end = text.rindex("}") + 1
        payload = json.loads(text[start:end])
        return model_class.model_validate(payload)
    except Exception:
        return fallback


def build_text_generation_provider(settings: AIPodcastSettings) -> TextGenerationProvider:
    if settings.use_google_provider:
        return GoogleGenAITextGenerationProvider(settings)
    return StubTextGenerationProvider()
