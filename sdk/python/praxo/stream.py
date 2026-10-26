from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

StreamKind = str

STREAM_VALUES = "values"
STREAM_UPDATES = "updates"
STREAM_MESSAGES = "messages"
STREAM_TASKS = "tasks"
STREAM_DEBUG = "debug"
STREAM_CHECKPOINT = "checkpoint"

STREAM_KINDS = (
    STREAM_VALUES,
    STREAM_UPDATES,
    STREAM_MESSAGES,
    STREAM_TASKS,
    STREAM_DEBUG,
    STREAM_CHECKPOINT,
)


@dataclass
class StreamPart:
    run_id: str
    session_id: str
    kind: str
    step: int = 0
    data: Any = None
    at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
