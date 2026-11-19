from __future__ import annotations

import sys
import unittest
from pathlib import Path

import praxo

FIXTURE = Path(__file__).parent / "fixtures" / "process_plugin.py"


class ProcessHostTests(unittest.TestCase):
    def config(self, **overrides: object) -> praxo.ProcessConfig:
        values = {
            "plugin_id": "com.example.echo",
            "path": sys.executable,
            "args": [str(FIXTURE)],
            "start_timeout": 5.0,
            "invoke_timeout": 2.0,
            "grace_period": 2.0,
        }
        values.update(overrides)
        return praxo.ProcessConfig(**values)

    def test_health_and_invoke(self) -> None:
        with praxo.ProcessHost(self.config()) as host:
            self.assertTrue(host.active)
            self.assertEqual(
                host.invoke("tool.provider", "echo", b'{"text":"hi"}'),
                b'{"text":"hi"}',
            )

    def test_unknown_method_and_denied(self) -> None:
        with praxo.ProcessHost(self.config()) as host:
            with self.assertRaises(praxo.PluginCallError) as denied:
                host.invoke("tool.provider", "denied")
            self.assertEqual(denied.exception.error_code, "CAPABILITY_DENIED")
            with self.assertRaises(praxo.PluginCallError) as missing:
                host.invoke("tool.provider", "missing")
            self.assertEqual(missing.exception.error_code, "NOT_FOUND")

    def test_invoke_before_start_fails(self) -> None:
        host = praxo.ProcessHost(self.config())
        with self.assertRaises(praxo.PluginCallError) as error:
            host.invoke("tool.provider", "echo", b"x")
        self.assertEqual(error.exception.error_code, "NOT_ACTIVE")

    def test_timeout_terminates_child(self) -> None:
        host = praxo.ProcessHost(self.config(invoke_timeout=0.2))
        host.start()
        try:
            with self.assertRaises(praxo.PluginCallError) as error:
                host.invoke("tool.provider", "block")
            self.assertEqual(error.exception.error_code, "TIMEOUT")
        finally:
            host.stop()
        self.assertFalse(host.active)


if __name__ == "__main__":
    unittest.main()
