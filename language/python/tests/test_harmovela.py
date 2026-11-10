from __future__ import annotations

import json
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.adapters.harmovela import HarmovelaSink
from praxo.errors import PraxoError
from praxo.event import Event


class Capture:
    def __init__(self, status: int = 201, body: bytes = b"") -> None:
        self.status = status
        self.body = body
        self.calls: list[tuple[str, str, dict[str, str], bytes]] = []

    def __call__(self, method, url, headers, body):
        self.calls.append((method, url, headers, body))
        return self.status, self.body


class HarmovelaSinkTest(unittest.IsolatedAsyncioTestCase):
    def event(self) -> Event:
        return Event(
            type="tool.call",
            session_id="s1",
            run_id="run-123",
            data={"name": "echo"},
            at=datetime(2026, 11, 10, 7, 0, 0, tzinfo=timezone.utc),
        )

    async def test_posts_envelope_and_merges_payload(self) -> None:
        capture = Capture()
        sink = HarmovelaSink("http://harmovela.test/aep/api/", transport=capture)
        await sink.emit(self.event())
        method, url, headers, body = capture.calls[0]
        self.assertEqual(method, "POST")
        self.assertEqual(url, "http://harmovela.test/aep/api/events")
        self.assertEqual(headers["content-type"], "application/json")
        envelope = json.loads(body)
        self.assertEqual(envelope["spec_version"], "0.2")
        self.assertEqual(envelope["id"], "run-123-1794294000000000000")
        self.assertEqual(envelope["type"], "tool.call")
        self.assertEqual(envelope["source"], "praxo-core")
        self.assertEqual(envelope["created_at"], "2026-11-10T07:00:00.000000000Z")
        self.assertEqual(
            envelope["payload"],
            {"name": "echo", "session_id": "s1", "run_id": "run-123"},
        )

    async def test_session_used_when_run_is_absent(self) -> None:
        capture = Capture()
        sink = HarmovelaSink(
            "http://harmovela.test/aep/api",
            source="custom",
            spec_version="0.3",
            transport=capture,
        )
        event = self.event()
        event.run_id = ""
        event.data = {"name": "echo", "session_id": "event-side", "run_id": "old"}
        await sink.emit(event)
        envelope = json.loads(capture.calls[0][3])
        self.assertEqual(envelope["source"], "custom")
        self.assertEqual(envelope["spec_version"], "0.3")
        self.assertTrue(envelope["id"].startswith("s1-"))
        self.assertEqual(
            envelope["payload"],
            {"name": "echo", "session_id": "s1", "run_id": "old"},
        )

    async def test_success_status_is_accepted(self) -> None:
        for status in (200, 201, 204, 299):
            with self.subTest(status=status):
                capture = Capture(status=status)
                sink = HarmovelaSink("http://harmovela.test", transport=capture)
                await sink.emit(self.event())
                self.assertEqual(len(capture.calls), 1)

    async def test_non_2xx_is_an_error_with_status_and_bounded_body(self) -> None:
        capture = Capture(status=503, body=b"service down " * 100)
        sink = HarmovelaSink("http://harmovela.test", transport=capture)
        with self.assertRaises(PraxoError) as raised:
            await sink.emit(self.event())
        message = str(raised.exception)
        self.assertIn("503", message)
        self.assertIn("service down", message)
        self.assertLessEqual(len(message), 600)


if __name__ == "__main__":
    unittest.main()
