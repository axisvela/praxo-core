from __future__ import annotations

import json
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.otel import OtelSink
from praxo.errors import PraxoError
from praxo.event import Event


class Capture:
    def __init__(self, status: int = 200, body: bytes = b"") -> None:
        self.status = status
        self.body = body
        self.calls: list[tuple[str, dict[str, str], bytes]] = []

    def __call__(self, url, headers, body):
        self.calls.append((url, headers, body))
        return self.status, self.body


class OtelSinkTest(unittest.IsolatedAsyncioTestCase):
    def event(self) -> Event:
        return Event(
            type="tool.call",
            session_id="s1",
            run_id="run-123",
            data={"name": "echo", "secret": "hidden"},
            at=datetime(2026, 11, 10, 7, 0, 0, tzinfo=timezone.utc),
        )

    async def test_posts_otlp_span_with_allowed_attributes(self) -> None:
        capture = Capture()
        sink = OtelSink(
            "http://otel.test/v1/traces",
            service_name="praxo-test",
            transport=capture,
            allowed_data_keys=["name"],
        )
        await sink.emit(self.event())
        url, headers, body = capture.calls[0]
        self.assertEqual(url, "http://otel.test/v1/traces")
        self.assertEqual(headers["content-type"], "application/json")
        payload = json.loads(body)
        resource = payload["resourceSpans"][0]["resource"]
        self.assertEqual(
            resource["attributes"][0]["value"]["stringValue"], "praxo-test"
        )
        span = payload["resourceSpans"][0]["scopeSpans"][0]["spans"][0]
        self.assertEqual(span["name"], "praxo.tool.call")
        self.assertEqual(len(span["traceId"]), 32)
        self.assertEqual(len(span["spanId"]), 16)
        self.assertEqual(span["startTimeUnixNano"], span["endTimeUnixNano"])
        attributes = {
            item["key"]: item["value"]["stringValue"]
            for item in span["attributes"]
        }
        self.assertEqual(attributes["praxo.event.type"], "tool.call")
        self.assertEqual(attributes["praxo.session.id"], "s1")
        self.assertEqual(attributes["praxo.run.id"], "run-123")
        self.assertEqual(attributes["praxo.event.data.name"], "echo")
        self.assertNotIn("praxo.event.data.secret", attributes)

    async def test_ids_are_deterministic(self) -> None:
        capture = Capture()
        sink = OtelSink(transport=capture)
        await sink.emit(self.event())
        await sink.emit(self.event())
        first = json.loads(capture.calls[0][2])["resourceSpans"][0][
            "scopeSpans"
        ][0]["spans"][0]
        second = json.loads(capture.calls[1][2])["resourceSpans"][0][
            "scopeSpans"
        ][0]["spans"][0]
        self.assertEqual(first["traceId"], second["traceId"])
        self.assertEqual(first["spanId"], second["spanId"])

    async def test_non_2xx_raises(self) -> None:
        sink = OtelSink(transport=Capture(status=503, body=b"down"))
        with self.assertRaises(PraxoError):
            await sink.emit(self.event())
