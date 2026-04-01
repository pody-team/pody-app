from __future__ import annotations

from app.notifications import NotificationClient


class _FakeResponse:
    def raise_for_status(self) -> None:
        return None


def test_send_show_created_does_not_send_placeholder_actor_avatar(monkeypatch) -> None:
    captured: dict[str, object] = {}

    def fake_post(url, *, json, headers, timeout):
        captured["url"] = url
        captured["json"] = json
        captured["headers"] = headers
        captured["timeout"] = timeout
        return _FakeResponse()

    monkeypatch.setattr("app.notifications.httpx.post", fake_post)
    client = NotificationClient(
        base_url="http://notification-service:8087",
        internal_api_key="internal-key",
    )

    client.send_show_created(
        user_id="creator-1",
        show_id="show-1",
        show_title="Tech Pulse",
        episode_count=3,
    )

    payload = captured["json"]
    assert payload["actor_snapshot"] == {"display_name": "Pody AI"}


def test_send_episode_created_does_not_send_placeholder_actor_avatar(monkeypatch) -> None:
    captured: dict[str, object] = {}

    def fake_post(url, *, json, headers, timeout):
        captured["url"] = url
        captured["json"] = json
        captured["headers"] = headers
        captured["timeout"] = timeout
        return _FakeResponse()

    monkeypatch.setattr("app.notifications.httpx.post", fake_post)
    client = NotificationClient(
        base_url="http://notification-service:8087",
        internal_api_key="internal-key",
    )

    client.send_episode_created(
        user_id="creator-1",
        show_id="show-1",
        show_title="Tech Pulse",
        episode_id="episode-1",
        episode_title="Tap 1",
        episode_number=1,
    )

    payload = captured["json"]
    assert payload["actor_snapshot"] == {"display_name": "Pody AI"}
