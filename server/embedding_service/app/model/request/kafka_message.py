from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class KafkaMessageContext:
    topic: str
    partition: int
    offset: int
    key: str | None
