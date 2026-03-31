from __future__ import annotations

from typing import Any

import httpx


class NotificationClient:
    def __init__(
        self,
        *,
        base_url: str | None,
        internal_api_key: str | None,
    ) -> None:
        self._base_url = (base_url or "").rstrip("/")
        self._internal_api_key = (internal_api_key or "").strip()

    @property
    def enabled(self) -> bool:
        return bool(self._base_url and self._internal_api_key)

    def send_show_created(
        self,
        *,
        user_id: str,
        show_id: str,
        show_title: str,
        episode_count: int,
    ) -> None:
        if not self.enabled:
            return

        payload: dict[str, Any] = {
            "user_id": user_id,
            "type": "milestone",
            "target_type": "show",
            "target_id": show_id,
            "title": "Show da san sang",
            "preview": f'"{show_title}" da tao xong.',
            "body": (
                f'"{show_title}" da duoc tao xong'
                f" voi {episode_count} episode AI."
            ),
            "actor_snapshot": {
                "display_name": "Pody AI",
                "avatar_url": "https://picsum.photos/seed/pody-ai/200/200",
            },
            "target_snapshot": {
                "title": show_title,
            },
        }

        response = httpx.post(
            f"{self._base_url}/internal/notifications/inbox",
            json=payload,
            headers={
                "X-Internal-Api-Key": self._internal_api_key,
            },
            timeout=10,
        )
        response.raise_for_status()

    def send_episode_created(
        self,
        *,
        user_id: str,
        show_id: str,
        show_title: str,
        episode_id: str,
        episode_title: str,
        episode_number: int,
    ) -> None:
        if not self.enabled:
            return

        payload: dict[str, Any] = {
            "user_id": user_id,
            "type": "new_episode",
            "target_type": "episode",
            "target_id": episode_id,
            "title": f"Tap {episode_number} da san sang",
            "preview": f'"{episode_title}" cua "{show_title}" da xong.',
            "body": (
                f'Tap {episode_number}: "{episode_title}" cua "{show_title}" '
                "da duoc tao xong."
            ),
            "actor_snapshot": {
                "display_name": "Pody AI",
                "avatar_url": "https://picsum.photos/seed/pody-ai/200/200",
            },
            "target_snapshot": {
                "title": episode_title,
            },
        }

        response = httpx.post(
            f"{self._base_url}/internal/notifications/inbox",
            json=payload,
            headers={
                "X-Internal-Api-Key": self._internal_api_key,
            },
            timeout=10,
        )
        response.raise_for_status()
