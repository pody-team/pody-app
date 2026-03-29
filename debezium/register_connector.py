from __future__ import annotations

import json
import os
import sys
import time
from urllib import error, request


def _env(key: str, default: str) -> str:
    value = os.getenv(key, "").strip()
    return value or default


CONNECT_URL = _env("DEBEZIUM_CONNECT_URL", "http://debezium-connect:8083").rstrip("/")
CONNECTOR_FILE = _env("DEBEZIUM_CONNECTOR_FILE", "/workspace/debezium/register-connector.json")
STARTUP_TIMEOUT_SECONDS = int(_env("DEBEZIUM_CONNECT_STARTUP_TIMEOUT_SECONDS", "120"))
POLL_INTERVAL_SECONDS = float(_env("DEBEZIUM_CONNECT_POLL_INTERVAL_SECONDS", "2"))


def main() -> int:
    payload = _load_connector_payload(CONNECTOR_FILE)
    connector_name = payload["name"]
    connector_config = payload["config"]

    _wait_for_connect()

    exists = _connector_exists(connector_name)
    if exists:
        _request_json(
            method="PUT",
            url=f"{CONNECT_URL}/connectors/{connector_name}/config",
            body=connector_config,
        )
        print(f"Updated Debezium connector: {connector_name}", flush=True)
    else:
        _request_json(
            method="POST",
            url=f"{CONNECT_URL}/connectors",
            body=payload,
        )
        print(f"Created Debezium connector: {connector_name}", flush=True)

    return 0


def _load_connector_payload(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as file:
        return json.load(file)


def _wait_for_connect() -> None:
    deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS

    while time.monotonic() < deadline:
        try:
            _request_json(method="GET", url=f"{CONNECT_URL}/connectors")
            print(f"Debezium Connect is reachable at {CONNECT_URL}", flush=True)
            return
        except Exception as exc:  # noqa: BLE001
            print(
                f"Waiting for Debezium Connect at {CONNECT_URL}: {exc}",
                flush=True,
            )
            time.sleep(POLL_INTERVAL_SECONDS)

    raise TimeoutError(
        f"Timed out waiting for Debezium Connect at {CONNECT_URL}"
    )


def _connector_exists(name: str) -> bool:
    try:
        _request_json(method="GET", url=f"{CONNECT_URL}/connectors/{name}")
        return True
    except error.HTTPError as exc:
        if exc.code == 404:
            return False
        raise


def _request_json(method: str, url: str, body: dict | None = None) -> dict | list | None:
    data: bytes | None = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = request.Request(url=url, method=method, data=data, headers=headers)
    with request.urlopen(req, timeout=15) as response:
        raw = response.read().decode("utf-8").strip()
        if not raw:
            return None
        return json.loads(raw)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"Debezium connector registration failed: {exc}", file=sys.stderr, flush=True)
        raise
