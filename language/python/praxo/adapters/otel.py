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

Transport = Callable[[str, dict[str, str], bytes], tuple[int, bytes]]


class OtelSink:
    def __init__(
        self,
        endpoint: str = "http://127.0.0.1:4318/v1/traces",
        service_name: str = "praxo-core",
        transport: Transport | None = None,
        allowed_data_keys: list[str] | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.endpoint = endpoint
        self.service_name = service_name or "praxo-core"
        self.transport = transport
        self.allowed_data_keys = tuple(allowed_data_keys or ())
        self.timeout = timeout

    async def emit(self, event: Event) -> None:
        body = json.dumps(
            self._payload(event), separators=(",", ":")
        ).encode("utf-8")
        status, response_body = await asyncio.to_thread(self._post, body)
        if status < 200 or status >= 300:
            text = response_body[:512].decode("utf-8", errors="replace").strip()
            raise PraxoError(f"otel: HTTP {status}: {text}")

    def _post(self, body: bytes) -> tuple[int, bytes]:
        headers = {"content-type": "application/json"}
        if self.transport is not None:
            return self.transport(self.endpoint, headers, body)
        request = HTTPRequest(
            self.endpoint, data=body, headers=headers, method="POST"
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                return response.status, response.read(512)
        except HTTPError as exc:
            return exc.code, exc.read(512)
        except URLError as exc:
            raise PraxoError(f"otel: {exc.reason}") from exc

    def _payload(self, event: Event) -> dict[str, object]:
        at = event.at
        if at.tzinfo is None:
            at = at.replace(tzinfo=timezone.utc)
        at = at.astimezone(timezone.utc)
        nanos = _unix_nanos(at)
        key = "|".join(
            (
                event.session_id,
                event.run_id or "",
                event.type,
                at.isoformat(),
                json.dumps(event.data, sort_keys=True, default=str),
            )
        )
        trace_id = f"{_fnv1a(key, 0xCBF29CE484222325):016x}{_fnv1a(key, 0x84222325CBF29CE4):016x}"
        span_id = f"{_fnv1a(key + '|span', 0x100000001B3):016x}"
        attributes = [
            _attribute("praxo.event.type", event.type),
        ]
        if event.session_id:
            attributes.append(_attribute("praxo.session.id", event.session_id))
        if event.run_id:
            attributes.append(_attribute("praxo.run.id", event.run_id))
        attributes.append(_attribute("praxo.event.at", at.isoformat().replace("+00:00", "Z")))
        for name in self.allowed_data_keys:
            if name in event.data:
                attributes.append(
                    _attribute(
                        "praxo.event.data." + name,
                        _text(event.data[name]),
                    )
                )
        return {
            "resourceSpans": [
                {
                    "resource": {
                        "attributes": [
                            _attribute("service.name", self.service_name)
                        ]
                    },
                    "scopeSpans": [
                        {
                            "scope": {"name": "praxo-core"},
                            "spans": [
                                {
                                    "traceId": trace_id,
                                    "spanId": span_id,
                                    "name": "praxo." + event.type,
                                    "kind": 1,
                                    "startTimeUnixNano": str(nanos),
                                    "endTimeUnixNano": str(nanos),
                                    "attributes": attributes,
                                }
                            ],
                        }
                    ],
                }
            ]
        }


def _attribute(key: str, value: str) -> dict[str, object]:
    return {"key": key, "value": {"stringValue": value}}


def _text(value: object) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, separators=(",", ":"), default=str)


def _unix_nanos(at: datetime) -> int:
    return int(at.timestamp()) * 1_000_000_000 + at.microsecond * 1_000


def _fnv1a(text: str, seed: int) -> int:
    value = seed & 0xFFFFFFFFFFFFFFFF
    for byte in text.encode("utf-8"):
        value ^= byte
        value = (value * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return value
