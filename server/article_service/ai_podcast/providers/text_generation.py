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
        target_minutes = max(2, int(payload.get("target_minutes") or 2))
        minimum_words = max(1, int(payload.get("minimum_words") or 1))
        source_count = len(((payload.get("research_pack") or {}).get("primary_sources") or []))
        outline = [
            "Mo dau va dat van de",
            "Tong hop cac y chinh tu nhom bai bao",
            "Mo rong boi canh va diem dang theo doi",
            "Ket lai va nhan manh dieu can nho",
        ]
        body_parts = [
            f"Xin chao, day la ban tin audio ve chu de {topic}.",
            f"Ban podcast nay tong hop {source_count} bai bao va huong toi thoi luong khoang {target_minutes} phut.",
            "Trong nhom bai bao ma ban vua chon, co mot so y chinh noi bat can luu y.",
        ]
        for section_index in range(max(target_minutes * 3, 1)):
            insight = str(key_insights[section_index % len(key_insights)]).strip()
            if insight:
                body_parts.append(
                    f"Diem noi bat {section_index + 1}: {insight}. Chi tiet nay dong vai tro quan trong trong buc tranh tong the, dong thoi mo ra nhieu tac dong va goc nhin tiep theo cho nguoi nghe."
                )
            body_parts.append(
                "Khi dat canh nhau, cac bai viet cho thay mot mach thong tin lien tuc, co nhieu diem noi nhau can theo doi, va moi bai bo sung them mot lop boi canh de nguoi nghe hieu van de sau hon."
            )
        body_parts.append("Ben canh do, co mot vai thong tin mo rong giup dat cac bai viet vao boi canh rong hon.")
        external_context = (synthesis.get("external_context") or [])[: max(3, min(6, target_minutes))]
        for item in external_context:
            body_parts.append(
                f"Boi canh them: {str(item).strip()}. Chi tiet bo sung nay giup ket noi cac su kien, xu huong, va nhung thay doi dang dien ra tren thi truong."
            )
        body_parts.append("Do la nhung diem noi bat nhat trong cum bai bao nay.")
        while len(" ".join(part for part in body_parts if part).split()) < minimum_words:
            body_parts.append(
                "Tong hop lai, cum bai viet nay khong chi cap nhat su kien moi ma con cho thay cach cac dien bien lien ket voi nhau, vi sao chung dang duoc quan tam, va nguoi nghe nen tiep tuc theo doi dieu gi trong vai ngay toi."
            )
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
