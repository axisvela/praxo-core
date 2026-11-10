"""Minimal stdio JSON-RPC 2.0 MCP client.

Errors use the Core ``PraxoError`` style with these codes:

- ``MCP_PROTOCOL``: invalid JSON-RPC, tool, or result shape.
- ``MCP_TRANSPORT``: child process or stdio transport failure.
- ``MCP_HANDSHAKE``: initialize result is missing a protocol version.
- ``MCP_PAGINATION``: repeated ``tools/list`` cursor.
- ``MCP_DUPLICATE_TOOL``: duplicate tool name across pages.
- ``MCP_TOOL_ERROR``: MCP tool returned ``isError``.
- ``MCP_RPC``: JSON-RPC error response.
- ``MCP_TIMEOUT``: initialize, list, or call exceeded its timeout.
- ``MCP_CLOSED``: the session closed with requests still pending.
"""

from __future__ import annotations

import asyncio
import copy
import json
import os
from dataclasses import dataclass, field
from typing import Any, Protocol, runtime_checkable

from .. import __version__ as _PRAXO_VERSION
from ..errors import (
    MCPClosedError,
    MCPDuplicateToolError,
    MCPHandshakeError,
    MCPPaginationError,
    MCPProtocolError,
    MCPRPCError,
    MCPTimeoutError,
    MCPToolError,
    MCPTransportError,
)
from ..model import ToolSpec
from ..tool import Registry, Tool

DEFAULT_PROTOCOL_VERSION = "2024-11-05"

__all__ = [
    "DEFAULT_PROTOCOL_VERSION",
    "MCPClient",
    "MCPServerConfig",
    "MCPTool",
    "MCPToolAdapter",
    "MCPTransport",
    "StdioTransport",
]


@dataclass
class MCPServerConfig:
    command: str
    args: list[str] = field(default_factory=list)
    env: dict[str, str] | None = None
    cwd: str | None = None


@runtime_checkable
class MCPTransport(Protocol):
    async def start(self) -> None: ...

    async def send(self, message: dict[str, Any]) -> None: ...

    async def receive(self) -> dict[str, Any] | None: ...

    async def close(self) -> None: ...


class StdioTransport:
    def __init__(
        self,
        config: MCPServerConfig,
        close_timeout: float = 5.0,
    ) -> None:
        self.config = config
        self.close_timeout = close_timeout
        self.process: asyncio.subprocess.Process | None = None

    async def start(self) -> None:
        if self.process is not None:
            return
        if not self.config.command:
            raise MCPTransportError("mcp: command is required")
        env = None
        if self.config.env is not None:
            env = dict(os.environ)
            env.update(self.config.env)
        try:
            self.process = await asyncio.create_subprocess_exec(
                self.config.command,
                *self.config.args,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
                env=env,
                cwd=self.config.cwd,
            )
        except OSError as exc:
            raise MCPTransportError(
                f"mcp: failed to start server: {exc}"
            ) from exc

    async def send(self, message: dict[str, Any]) -> None:
        process = self.process
        if process is None or process.stdin is None:
            raise MCPTransportError("mcp: transport is not started")
        line = (
            json.dumps(
                message,
                ensure_ascii=False,
                separators=(",", ":"),
            )
            + "\n"
        )
        try:
            process.stdin.write(line.encode("utf-8"))
            await process.stdin.drain()
        except (BrokenPipeError, ConnectionResetError, OSError) as exc:
            raise MCPTransportError(
                f"mcp: failed to write to server: {exc}"
            ) from exc

    async def receive(self) -> dict[str, Any] | None:
        process = self.process
        if process is None or process.stdout is None:
            return None
        while True:
            line = await process.stdout.readline()
            if not line:
                return None
            text = line.decode("utf-8", errors="replace").strip()
            if not text:
                continue
            try:
                message = json.loads(text)
            except ValueError as exc:
                raise MCPProtocolError(
                    "mcp: server sent invalid JSON"
                ) from exc
            if not isinstance(message, dict):
                raise MCPProtocolError(
                    "mcp: server sent a non-object JSON-RPC message"
                )
            return message

    async def close(self) -> None:
        process = self.process
        if process is None:
            return
        if process.stdin is not None and not process.stdin.is_closing():
            process.stdin.close()
            try:
                await process.stdin.wait_closed()
            except (AttributeError, BrokenPipeError, OSError):
                pass
        try:
            await asyncio.wait_for(
                process.wait(), timeout=self.close_timeout
            )
        except asyncio.TimeoutError:
            process.terminate()
            try:
                await asyncio.wait_for(
                    process.wait(), timeout=self.close_timeout
                )
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()


class MCPClient:
    def __init__(
        self,
        config: MCPServerConfig | None = None,
        *,
        transport: MCPTransport | None = None,
        timeout: float = 30.0,
        client_name: str = "praxo-core",
        client_version: str | None = None,
        protocol_version: str = DEFAULT_PROTOCOL_VERSION,
    ) -> None:
        if transport is None:
            if config is None:
                raise ValueError("mcp: config or transport is required")
            transport = StdioTransport(config)
        self.transport = transport
        self.timeout = timeout
        self.client_name = client_name or "praxo-core"
        self.client_version = client_version or _PRAXO_VERSION
        self.requested_protocol_version = protocol_version
        self.protocol_version = ""
        self.server_info: dict[str, Any] = {}
        self.server_capabilities: dict[str, Any] = {}
        self._next_id = 1
        self._pending: dict[int, asyncio.Future[dict[str, Any]]] = {}
        self._reader: asyncio.Task[None] | None = None
        self._write_lock = asyncio.Lock()
        self._connected = False
        self._transport_closed = False
        self._read_error: BaseException | None = None

    @property
    def connected(self) -> bool:
        return self._connected

    async def __aenter__(self) -> MCPClient:
        await self.connect()
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        await self.close()

    async def connect(self) -> MCPClient:
        if self._connected:
            return self
        if self._transport_closed:
            raise MCPClosedError("mcp: client is closed")
        try:
            await self.transport.start()
            self._reader = asyncio.create_task(
                self._read_loop(),
                name="praxo-mcp-reader",
            )
            result = await self._request(
                "initialize",
                {
                    "protocolVersion": self.requested_protocol_version,
                    "capabilities": {},
                    "clientInfo": {
                        "name": self.client_name,
                        "version": self.client_version,
                    },
                },
            )
            version = result.get("protocolVersion")
            if not isinstance(version, str) or not version:
                raise MCPHandshakeError(
                    "mcp: initialize returned no protocol version"
                )
            self.protocol_version = version
            info = result.get("serverInfo")
            self.server_info = dict(info) if isinstance(info, dict) else {}
            capabilities = result.get("capabilities")
            self.server_capabilities = (
                dict(capabilities)
                if isinstance(capabilities, dict)
                else {}
            )
            await self._notify("notifications/initialized")
            self._connected = True
            return self
        except BaseException:
            try:
                await self.close()
            except BaseException:
                pass
            raise

    async def close(self) -> None:
        if self._transport_closed:
            return
        self._transport_closed = True
        self._connected = False
        reader = self._reader
        self._reader = None
        if reader is not None and not reader.done():
            reader.cancel()
            try:
                await reader
            except asyncio.CancelledError:
                pass
            except Exception:
                pass
        try:
            await self.transport.close()
        finally:
            self._fail_pending(MCPClosedError("mcp: client closed"))

    async def list_tools(
        self,
        *,
        timeout: float | None = None,
    ) -> list[MCPTool]:
        tools: list[MCPTool] = []
        seen_names: set[str] = set()
        seen_cursors: set[str] = set()
        cursor: str | None = None
        while True:
            params: dict[str, Any] = {}
            if cursor:
                params["cursor"] = cursor
            result = await self._request(
                "tools/list",
                params or None,
                timeout,
            )
            raw_tools = result.get("tools")
            if raw_tools is None:
                raw_tools = []
            if not isinstance(raw_tools, list):
                raise MCPProtocolError(
                    "mcp: tools/list tools must be a list"
                )
            for raw in raw_tools:
                tool = _parse_tool(raw)
                if tool.name in seen_names:
                    raise MCPDuplicateToolError(
                        f"mcp: duplicate tool {tool.name}"
                    )
                seen_names.add(tool.name)
                tools.append(tool)
            next_cursor = result.get("nextCursor")
            if next_cursor is None or next_cursor == "":
                break
            if not isinstance(next_cursor, str):
                raise MCPProtocolError(
                    "mcp: tools/list nextCursor must be a string"
                )
            if next_cursor in seen_cursors:
                raise MCPPaginationError(
                    "mcp: repeated tool pagination cursor"
                )
            seen_cursors.add(next_cursor)
            cursor = next_cursor
        tools.sort(key=lambda item: item.name)
        return tools

    async def call_tool(
        self,
        name: str,
        arguments: dict[str, Any] | None = None,
        *,
        timeout: float | None = None,
    ) -> Any:
        if not isinstance(name, str) or not name:
            raise ValueError("mcp: tool name is required")
        args = {} if arguments is None else arguments
        if not isinstance(args, dict):
            raise ValueError("mcp: tool arguments must be an object")
        result = await self._request(
            "tools/call",
            {"name": name, "arguments": args},
            timeout,
        )
        if result.get("isError"):
            raise MCPToolError(
                f"mcp: tool {name} failed: {_text_content(result)}"
            )
        if result.get("structuredContent") is not None:
            return result["structuredContent"]
        texts = _text_contents(result)
        if not texts:
            return None
        if len(texts) == 1:
            return texts[0]
        return texts

    async def register_tools(self, registry: Registry) -> list[Tool]:
        tools = await self.list_tools()
        adapters = [MCPToolAdapter(self, tool) for tool in tools]
        for adapter in adapters:
            registry.register(adapter)
        return adapters

    async def _request(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> dict[str, Any]:
        if self._transport_closed:
            raise MCPClosedError("mcp: client is closed")
        if self._read_error is not None:
            raise MCPClosedError(
                "mcp: connection closed"
            ) from self._read_error
        request_id = self._next_id
        self._next_id += 1
        loop = asyncio.get_running_loop()
        future: asyncio.Future[dict[str, Any]] = loop.create_future()
        self._pending[request_id] = future
        message: dict[str, Any] = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
        }
        if params is not None:
            message["params"] = params
        effective = self.timeout if timeout is None else timeout
        try:
            await self._send(message)
            if effective is not None and effective > 0:
                response = await asyncio.wait_for(future, effective)
            else:
                response = await future
        except asyncio.TimeoutError as exc:
            self._pending.pop(request_id, None)
            await self._cancel(request_id, "timeout")
            raise MCPTimeoutError(
                f"mcp: {method} timed out after {effective} seconds"
            ) from exc
        except asyncio.CancelledError:
            self._pending.pop(request_id, None)
            await self._cancel(request_id, "cancelled")
            raise
        except BaseException:
            self._pending.pop(request_id, None)
            raise
        if "error" in response:
            raise _rpc_error(method, response["error"])
        result = response.get("result")
        if result is None:
            return {}
        if not isinstance(result, dict):
            raise MCPProtocolError(
                f"mcp: {method} result must be an object"
            )
        return result

    async def _notify(
        self,
        method: str,
        params: dict[str, Any] | None = None,
    ) -> None:
        message: dict[str, Any] = {
            "jsonrpc": "2.0",
            "method": method,
        }
        if params is not None:
            message["params"] = params
        await self._send(message)

    async def _cancel(self, request_id: int, reason: str) -> None:
        try:
            await asyncio.wait_for(
                self._send(
                    {
                        "jsonrpc": "2.0",
                        "method": "notifications/cancelled",
                        "params": {
                            "requestId": request_id,
                            "reason": reason,
                        },
                    }
                ),
                timeout=1.0,
            )
        except BaseException:
            pass

    async def _send(self, message: dict[str, Any]) -> None:
        async with self._write_lock:
            await self.transport.send(message)

    async def _read_loop(self) -> None:
        try:
            while True:
                message = await self.transport.receive()
                if message is None:
                    break
                self._dispatch(message)
        except asyncio.CancelledError:
            raise
        except BaseException as exc:
            self._read_error = exc
        finally:
            self._fail_pending(
                self._read_error
                or MCPClosedError("mcp: connection closed")
            )

    def _dispatch(self, message: dict[str, Any]) -> None:
        if message.get("jsonrpc") != "2.0":
            raise MCPProtocolError("mcp: invalid JSON-RPC version")
        request_id = message.get("id")
        if request_id is None:
            return
        future = self._pending.pop(request_id, None)
        if future is not None and not future.done():
            future.set_result(message)

    def _fail_pending(self, error: BaseException) -> None:
        pending = list(self._pending.values())
        self._pending.clear()
        for future in pending:
            if not future.done():
                future.set_exception(error)


@dataclass(frozen=True)
class MCPTool:
    name: str
    description: str = ""
    input_schema: dict[str, Any] = field(default_factory=dict)
    title: str = ""
    annotations: dict[str, Any] = field(default_factory=dict)

    @property
    def parameters(self) -> dict[str, Any]:
        return self.input_schema

    def to_spec(self) -> ToolSpec:
        return ToolSpec(
            name=self.name,
            description=self.description,
            parameters=copy.deepcopy(self.input_schema),
        )


class MCPToolAdapter:
    def __init__(self, client: MCPClient, tool: MCPTool) -> None:
        self.client = client
        self.tool = tool
        self.name = tool.name
        self.description = tool.description
        self.parameters = tool.input_schema

    async def invoke(self, args: dict[str, Any]) -> Any:
        return await self.client.call_tool(self.name, args)

    def spec(self) -> ToolSpec:
        return self.tool.to_spec()


def _parse_tool(raw: Any) -> MCPTool:
    if not isinstance(raw, dict):
        raise MCPProtocolError("mcp: tool definition must be an object")
    name = raw.get("name")
    if not isinstance(name, str) or not name:
        raise MCPProtocolError("mcp: tool name is required")
    schema = raw.get("inputSchema")
    if not isinstance(schema, dict):
        raise MCPProtocolError(f"mcp: missing input schema for {name}")
    description = raw.get("description")
    title = raw.get("title")
    annotations = raw.get("annotations")
    return MCPTool(
        name=name,
        description=description if isinstance(description, str) else "",
        input_schema=copy.deepcopy(schema),
        title=title if isinstance(title, str) else "",
        annotations=(
            copy.deepcopy(annotations)
            if isinstance(annotations, dict)
            else {}
        ),
    )


def _text_contents(result: dict[str, Any]) -> list[str]:
    content = result.get("content")
    if not isinstance(content, list):
        return []
    texts: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") != "text":
            continue
        text = block.get("text")
        if isinstance(text, str):
            texts.append(text)
    return texts


def _text_content(result: dict[str, Any]) -> str:
    return "\n".join(_text_contents(result))


def _rpc_error(method: str, error: Any) -> MCPRPCError:
    if not isinstance(error, dict):
        raise MCPProtocolError(
            f"mcp: {method} returned an invalid error object"
        )
    rpc_code = error.get("code")
    message = error.get("message")
    if not isinstance(message, str) or not message:
        message = f"{method} failed"
    return MCPRPCError(
        f"mcp: {method}: {message}",
        rpc_code=rpc_code if isinstance(rpc_code, int) else None,
        data=error.get("data"),
    )
