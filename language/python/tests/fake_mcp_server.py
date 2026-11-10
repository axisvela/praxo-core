from __future__ import annotations

import json
import sys
from typing import Any

PROTOCOL_VERSION = "2024-11-05"

TOOLS: dict[str, dict[str, Any]] = {
    "echo": {
        "name": "echo",
        "description": "Echo input",
        "inputSchema": {
            "type": "object",
            "properties": {"text": {"type": "string"}},
            "required": ["text"],
        },
    },
    "add": {
        "name": "add",
        "description": "Add two integers",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {"type": "integer"},
                "b": {"type": "integer"},
            },
            "required": ["a", "b"],
        },
    },
    "fail": {
        "name": "fail",
        "description": "Always fails",
        "inputSchema": {"type": "object", "properties": {}},
    },
    "multi": {
        "name": "multi",
        "description": "Return two text blocks",
        "inputSchema": {"type": "object", "properties": {}},
    },
}


def main() -> int:
    mode = _mode(sys.argv[1:])
    initialized = False
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if not isinstance(message, dict):
            continue
        method = message.get("method")
        request_id = message.get("id")
        if method == "initialize":
            _respond(
                request_id,
                {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {"tools": {}},
                    "serverInfo": {
                        "name": "fake-mcp",
                        "version": "1.0.0",
                    },
                },
            )
        elif method == "notifications/initialized":
            initialized = True
        elif method == "notifications/cancelled":
            continue
        elif method == "tools/list":
            if not initialized:
                _error(request_id, -32002, "not initialized")
                continue
            params = message.get("params") or {}
            _respond(request_id, _list_tools(mode, params))
        elif method == "tools/call":
            if not initialized:
                _error(request_id, -32002, "not initialized")
                continue
            params = message.get("params") or {}
            _respond(request_id, _call_tool(params))
        elif request_id is not None:
            _error(request_id, -32601, "method not found")
    return 0


def _mode(args: list[str]) -> str:
    if len(args) >= 2 and args[0] == "--mode":
        return args[1]
    return "default"


def _list_tools(mode: str, params: dict[str, Any]) -> dict[str, Any]:
    cursor = params.get("cursor")
    if mode == "repeated-cursor":
        label = "start" if not cursor else cursor
        return {
            "tools": [_generic_tool(f"loop-{label}")],
            "nextCursor": "loop",
        }
    if mode == "duplicate-name":
        if not cursor:
            return {
                "tools": [_generic_tool("dup")],
                "nextCursor": "page-2",
            }
        return {"tools": [_generic_tool("dup")]}
    if not cursor:
        return {
            "tools": [TOOLS["echo"], TOOLS["add"]],
            "nextCursor": "page-2",
        }
    if cursor == "page-2":
        return {"tools": [TOOLS["fail"], TOOLS["multi"]]}
    return {"tools": []}


def _generic_tool(name: str) -> dict[str, Any]:
    return {
        "name": name,
        "description": "generic",
        "inputSchema": {"type": "object", "properties": {}},
    }


def _call_tool(params: dict[str, Any]) -> dict[str, Any]:
    name = params.get("name")
    arguments = params.get("arguments") or {}
    if name == "add":
        total = int(arguments.get("a", 0)) + int(arguments.get("b", 0))
        return {
            "content": [{"type": "text", "text": str(total)}],
            "structuredContent": {"sum": total},
            "isError": False,
        }
    if name == "echo":
        return {
            "content": [
                {
                    "type": "text",
                    "text": str(arguments.get("text", "")),
                }
            ],
            "isError": False,
        }
    if name == "multi":
        return {
            "content": [
                {"type": "text", "text": "one"},
                {"type": "text", "text": "two"},
            ],
            "isError": False,
        }
    if name == "fail":
        return {
            "content": [{"type": "text", "text": "boom"}],
            "isError": True,
        }
    return {
        "content": [
            {"type": "text", "text": f"unknown tool {name}"}
        ],
        "isError": True,
    }


def _respond(request_id: Any, result: Any) -> None:
    _write(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": result,
        }
    )


def _error(request_id: Any, code: int, message: str) -> None:
    _write(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {"code": code, "message": message},
        }
    )


def _write(message: dict[str, Any]) -> None:
    sys.stdout.write(
        json.dumps(message, ensure_ascii=False, separators=(",", ":"))
        + "\n"
    )
    sys.stdout.flush()


if __name__ == "__main__":
    raise SystemExit(main())
