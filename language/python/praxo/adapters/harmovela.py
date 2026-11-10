from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request as HTTPRequest
from urllib.request import urlopen

from ..errors import PraxoError
from ..event import Event

Transport = Callable[[str, str, dict[str, str], bytes], tuple[int, bytes]]


class HarmovelaSink:
    def __init__(
        self,
        base_url: str,
        source: str = "praxo-core",
        spec_version: str = "0.2",
        transport: Transport | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.base_url = base_url
        self.source = source or "praxo-core"
        self.spec_version = spec_version or "0.2"
        self.transport = transport
        self.timeout = timeout

    async def emit(self, event: Event) -> None:
        body = json.dumps(self._envelope(event), separators=(",", ":")).encode(
            "utf-8"
        )
        status, response_body = await asyncio.to_thread(self._post, body)
        if status < 200 or status >= 300:
            text = response_body[:512].decode("utf-8", errors="replace").strip()
            raise PraxoError(f"harmovela: HTTP {status}: {text}")

    def _post(self, body: bytes) -> tuple[int, bytes]:
        url = self.base_url.rstrip("/") + "/events"
        headers = {"content-type": "application/json"}
        if self.transport is not None:
            return self.transport("POST", url, headers, body)
        request = HTTPRequest(url, data=body, headers=headers, method="POST")
        try:
            with urlopen(request, timeout=self.timeout) as response:
                return response.status, response.read(512)
        except HTTPError as exc:
            return exc.code, exc.read(512)
        except URLError as exc:
            raise PraxoError(f"harmovela: {exc.reason}") from exc

    def _envelope(self, event: Event) -> dict[str, object]:
        at = event.at
        if at.tzinfo is None:
            at = at.replace(tzinfo=timezone.utc)
        at = at.astimezone(timezone.utc)
        payload = dict(event.data)
        if event.session_id:
            payload["session_id"] = event.session_id
        if event.run_id:
            payload["run_id"] = event.run_id
        return {
            "spec_version": self.spec_version,
            "id": _event_id(event, at),
            "type": event.type,
            "source": self.source,
            "created_at": _rfc3339_nanos(at),
            "payload": payload,
        }


def _event_id(event: Event, at: datetime) -> str:
    prefix = event.run_id or event.session_id or "event"
    seconds = int(at.timestamp())
    nanos = seconds * 1_000_000_000 + at.microsecond * 1_000
    return f"{prefix}-{nanos}"


def _rfc3339_nanos(at: datetime) -> str:
    base = at.strftime("%Y-%m-%dT%H:%M:%S")
    nanos = at.microsecond * 1_000
    return f"{base}.{nanos:09d}Z"
