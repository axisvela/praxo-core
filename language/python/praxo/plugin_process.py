from __future__ import annotations

import base64
import json
import os
import queue
import secrets
import subprocess
import threading
import time
from dataclasses import dataclass, field

from .errors import PraxoError

PROTOCOL_VERSION = 1
CONTROL_SERVICE = "host.control"
METHOD_HEALTH = "health"
METHOD_SHUTDOWN = "shutdown"
METHOD_CANCEL = "cancel"
DEFAULT_TOKEN_ENV = "PRAXOVELA_PLUGIN_TOKEN"

CALL_ERROR_CODES = frozenset(
    {
        "CAPABILITY_DENIED",
        "NOT_ACTIVE",
        "NOT_FOUND",
        "INVALID_REQUEST",
        "TIMEOUT",
        "INTERNAL",
        "CANCELED",
    }
)


class PluginCallError(PraxoError):
    code = "PLUGIN_CALL"

    def __init__(self, error_code: str, message: str = "") -> None:
        super().__init__(message or error_code)
        self.error_code = (
            error_code if error_code in CALL_ERROR_CODES else "INTERNAL"
        )


@dataclass
class ProcessConfig:
    plugin_id: str
    path: str
    args: list[str] = field(default_factory=list)
    dir: str | None = None
    env: dict[str, str] | None = None
    token: str = ""
    token_env_var: str = DEFAULT_TOKEN_ENV
    start_timeout: float = 10.0
    invoke_timeout: float = 30.0
    grace_period: float = 5.0
    max_frame: int = 8 << 20


class ProcessHost:
    def __init__(self, config: ProcessConfig) -> None:
        if not config.plugin_id:
            raise PraxoError("plugin: PluginID is required")
        if not config.path:
            raise PraxoError("plugin: path is required")
        self.config = config
        self._token = config.token or secrets.token_hex(32)
        self._process: subprocess.Popen[bytes] | None = None
        self._responses: queue.Queue[bytes | None] = queue.Queue()
        self._stderr = bytearray()
        self._lock = threading.Lock()
        self._seq = 0
        self._active = False
        self._reader: threading.Thread | None = None
        self._stderr_reader: threading.Thread | None = None

    @property
    def plugin_id(self) -> str:
        return self.config.plugin_id

    @property
    def active(self) -> bool:
        return self._active

    def start(self) -> None:
        if self._process is not None:
            raise PraxoError("plugin: host already started")
        env = dict(os.environ if self.config.env is None else self.config.env)
        env[self.config.token_env_var] = self._token
        self._process = subprocess.Popen(
            [self.config.path, *self.config.args],
            cwd=self.config.dir,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        self._reader = threading.Thread(target=self._read_stdout, daemon=True)
        self._stderr_reader = threading.Thread(
            target=self._read_stderr, daemon=True
        )
        self._reader.start()
        self._stderr_reader.start()
        try:
            self._call(
                CONTROL_SERVICE,
                METHOD_HEALTH,
                b"",
                self.config.start_timeout,
            )
        except Exception:
            self._terminate()
            raise
        self._active = True

    def invoke(
        self,
        service: str,
        method: str,
        payload: bytes = b"",
        timeout: float | None = None,
    ) -> bytes:
        if not self._active:
            raise PluginCallError("NOT_ACTIVE", "plugin: host is not active")
        return self._call(
            service,
            method,
            payload,
            self.config.invoke_timeout if timeout is None else timeout,
        )

    def stop(self) -> None:
        if self._process is None:
            return
        try:
            if self._active:
                self._call(
                    CONTROL_SERVICE,
                    METHOD_SHUTDOWN,
                    b"",
                    self.config.grace_period,
                )
        except Exception:
            pass
        self._active = False
        process = self._process
        try:
            process.wait(timeout=self.config.grace_period)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=self.config.grace_period)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        self._close_pipes()

    def stderr_text(self) -> str:
        return self._stderr.decode("utf-8", errors="replace")

    def _call(
        self,
        service: str,
        method: str,
        payload: bytes,
        timeout: float,
    ) -> bytes:
        with self._lock:
            self._seq += 1
            request_id = f"req-{self._seq}"
            frame = {
                "id": request_id,
                "version": PROTOCOL_VERSION,
                "plugin_id": self.config.plugin_id,
                "service": service,
                "method": method,
                "token": self._token,
                "payload": base64.b64encode(payload).decode("ascii"),
            }
            encoded = json.dumps(frame, separators=(",", ":")).encode("utf-8")
            if len(encoded) > self.config.max_frame:
                raise PluginCallError(
                    "INVALID_REQUEST", "plugin: request frame too large"
                )
            process = self._process
            if process is None or process.stdin is None:
                raise PluginCallError("INTERNAL", "plugin: process is closed")
            try:
                process.stdin.write(encoded + b"\n")
                process.stdin.flush()
            except (BrokenPipeError, OSError) as exc:
                raise PluginCallError("INTERNAL", str(exc)) from exc
            try:
                raw = self._responses.get(timeout=timeout)
            except queue.Empty:
                self._request_cancel(request_id)
                raise PluginCallError(
                    "TIMEOUT", "plugin: invocation timed out"
                ) from None
        if raw is None:
            raise PluginCallError("INTERNAL", self.stderr_text()[:512])
        if len(raw) > self.config.max_frame:
            raise PluginCallError("INTERNAL", "plugin: response frame too large")
        try:
            response = json.loads(raw)
        except ValueError as exc:
            raise PluginCallError("INTERNAL", f"plugin: invalid response: {exc}") from exc
        if not isinstance(response, dict):
            raise PluginCallError("INTERNAL", "plugin: response is not an object")
        if response.get("id") != request_id:
            raise PluginCallError("INTERNAL", "plugin: mismatched response id")
        if not response.get("ok", False):
            raise PluginCallError(
                str(response.get("code", "INTERNAL")),
                str(response.get("message", "")),
            )
        payload_text = response.get("payload", "")
        if not isinstance(payload_text, str):
            raise PluginCallError("INTERNAL", "plugin: invalid payload")
        try:
            return base64.b64decode(payload_text.encode("ascii"))
        except Exception as exc:
            raise PluginCallError("INTERNAL", "plugin: invalid payload") from exc

    def _request_cancel(self, request_id: str) -> None:
        process = self._process
        if process is None or process.stdin is None:
            return
        frame = {
            "id": request_id,
            "version": PROTOCOL_VERSION,
            "plugin_id": self.config.plugin_id,
            "service": CONTROL_SERVICE,
            "method": METHOD_CANCEL,
            "token": self._token,
        }
        try:
            process.stdin.write(
                json.dumps(frame, separators=(",", ":")).encode("utf-8") + b"\n"
            )
            process.stdin.flush()
        except (BrokenPipeError, OSError):
            pass

    def _read_stdout(self) -> None:
        process = self._process
        assert process is not None and process.stdout is not None
        while True:
            line = process.stdout.readline()
            if not line:
                break
            self._responses.put(line.strip())
        self._responses.put(None)

    def _read_stderr(self) -> None:
        process = self._process
        assert process is not None and process.stderr is not None
        while True:
            chunk = process.stderr.read(4096)
            if not chunk:
                break
            if len(self._stderr) < 16 << 10:
                self._stderr.extend(chunk[: (16 << 10) - len(self._stderr)])

    def _terminate(self) -> None:
        self._active = False
        process = self._process
        if process is not None:
            try:
                process.terminate()
                process.wait(timeout=1.0)
            except Exception:
                try:
                    process.kill()
                    process.wait()
                except Exception:
                    pass
        self._close_pipes()

    def _close_pipes(self) -> None:
        process = self._process
        if process is not None:
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream is not None:
                    try:
                        stream.close()
                    except Exception:
                        pass
        self._process = None

    def __enter__(self) -> ProcessHost:
        self.start()
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.stop()
