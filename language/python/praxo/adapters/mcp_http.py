"""Streamable HTTP JSON-RPC 2.0 MCP transport.

This transport implements the 2025-03-26 Streamable HTTP mapping. It uses only
the Python standard library and supports JSON or SSE POST responses.
"""

from __future__ import annotations

import asyncio
import ipaddress
import json
from dataclasses import dataclass, field
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest
from urllib.parse import urlsplit

from ..errors import MCPProtocolError, MCPTransportError
from .mcp import DEFAULT_PROTOCOL_VERSION

HTTP_PROTOCOL_VERSION = "2025-03-26"
DEFAULT_ACCEPT = "application/json, text/event-stream"

__all__ = [
    "HTTP_PROTOCOL_VERSION",
    "StreamableHTTPConfig",
    "StreamableHTTPTransport",
]


@dataclass
class StreamableHTTPConfig:
    endpoint: str
    headers: dict[str, str] = field(default_factory=dict)
    protocol_version: str = HTTP_PROTOCOL_VERSION
    timeout: float = 30.0


class StreamableHTTPTransport:
    def __init__(self, config: StreamableHTTPConfig) -> None:
        self.config = config
        self.protocol_version = config.protocol_version or DEFAULT_PROTOCOL_VERSION
        self.session_id = ""
        self._incoming: asyncio.Queue[dict[str, Any] | None] = (
            asyncio.Queue()
        )
        self._started = False
        self._closed = False

    async def start(self) -> None:
        if self._started:
            return
        parts = urlsplit(self.config.endpoint)
        if parts.scheme not in ("http", "https") or not parts.netloc:
            raise MCPTransportError("mcp: invalid HTTP endpoint")
        if parts.scheme == "http" and not _loopback(parts.hostname):
            raise MCPTransportError(
                "mcp: HTTP endpoint must use HTTPS"
            )
        self._started = True

    async def send(self, message: dict[str, Any]) -> None:
        if not self._started or self._closed:
            raise MCPTransportError("mcp: transport is closed")
        body = json.dumps(
            message,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        headers = {
            "content-type": "application/json",
            "accept": DEFAULT_ACCEPT,
            "mcp-protocol-version": self.protocol_version,
            **self.config.headers,
        }
        if self.session_id:
            headers["mcp-session-id"] = self.session_id
        status, response_headers, payload = await asyncio.to_thread(
            self._post,
            body,
            headers,
        )
        session_id = _header(response_headers, "Mcp-Session-Id")
        if session_id:
            self.session_id = session_id
        if status in (202, 204) or not payload:
            return
        content_type = _header(response_headers, "Content-Type") or ""
        messages = _parse_messages(content_type, payload)
        for item in messages:
            if not isinstance(item, dict):
                raise MCPProtocolError(
                    "mcp: server sent a non-object JSON-RPC message"
                )
            result = item.get("result")
            if isinstance(result, dict):
                version = result.get("protocolVersion")
                if isinstance(version, str) and version:
                    self.protocol_version = version
            await self._incoming.put(item)

    async def receive(self) -> dict[str, Any] | None:
        return await self._incoming.get()

    async def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self.session_id:
            try:
                await asyncio.to_thread(self._delete)
            except Exception:
                pass
        await self._incoming.put(None)

    def _post(
        self,
        body: bytes,
        headers: dict[str, str],
    ) -> tuple[int, dict[str, str], bytes]:
        request = urlrequest.Request(
            self.config.endpoint,
            data=body,
            headers=headers,
            method="POST",
        )
        try:
            with urlrequest.urlopen(
                request,
                timeout=self.config.timeout,
            ) as response:
                return response.status, dict(response.headers), response.read()
        except urlerror.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:512]
            raise MCPTransportError(
                f"mcp: HTTP {exc.code}: {detail}"
            ) from exc
        except urlerror.URLError as exc:
            raise MCPTransportError(
                f"mcp: HTTP transport failed: {exc.reason}"
            ) from exc

    def _delete(self) -> None:
        request = urlrequest.Request(
            self.config.endpoint,
            headers={
                "mcp-session-id": self.session_id,
                "mcp-protocol-version": self.protocol_version,
                **self.config.headers,
            },
            method="DELETE",
        )
        try:
            with urlrequest.urlopen(
                request,
                timeout=self.config.timeout,
            ):
                pass
        except (urlerror.HTTPError, urlerror.URLError):
            pass


def _parse_messages(content_type: str, payload: bytes) -> list[Any]:
    text = payload.decode("utf-8", errors="replace")
    if "text/event-stream" in content_type.lower():
        return _parse_sse(text)
    try:
        value = json.loads(text)
    except ValueError as exc:
        raise MCPProtocolError("mcp: server sent invalid JSON") from exc
    if isinstance(value, list):
        return value
    return [value]


def _parse_sse(text: str) -> list[Any]:
    messages: list[Any] = []
    data: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip("\r")
        if not line:
            if data:
                messages.append(_parse_sse_data("\n".join(data)))
                data = []
            continue
        if line.startswith(":"):
            continue
        if line.startswith("data:"):
            data.append(line[5:].lstrip(" "))
    if data:
        messages.append(_parse_sse_data("\n".join(data)))
    return messages


def _parse_sse_data(text: str) -> Any:
    try:
        return json.loads(text)
    except ValueError as exc:
        raise MCPProtocolError("mcp: server sent invalid SSE JSON") from exc


def _header(headers: dict[str, str], name: str) -> str:
    lowered = name.lower()
    for key, value in headers.items():
        if key.lower() == lowered:
            return value
    return ""


def _loopback(host: str | None) -> bool:
    if host is None:
        return False
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False
