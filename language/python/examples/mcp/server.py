from __future__ import annotations

import json
import sys
from typing import Any

PROTOCOL_VERSION = "2024-11-05"

TOOLS = [
    {
        "name": "echo",
        "description": "Echo input",
        "inputSchema": {
            "type": "object",
            "properties": {"text": {"type": "string"}},
            "required": ["text"],
        },
    },
    {
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
]


def main() -> int:
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
            respond(request_id, {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "example-mcp", "version": "1.0.0"},
            })
        elif method == "notifications/initialized":
            initialized = True
        elif method == "tools/list" and initialized:
            respond(request_id, {"tools": TOOLS})
        elif method == "tools/call" and initialized:
            respond(request_id, call_tool(message.get("params") or {}))
        elif request_id is not None:
            error(request_id, -32601, "method not found")
    return 0


def call_tool(params: dict[str, Any]) -> dict[str, Any]:
    name = params.get("name")
    arguments = params.get("arguments") or {}
    if name == "echo":
        return {
            "content": [{"type": "text", "text": str(arguments.get("text", ""))}],
            "isError": False,
        }
    if name == "add":
        total = int(arguments.get("a", 0)) + int(arguments.get("b", 0))
        return {
            "content": [{"type": "text", "text": str(total)}],
            "structuredContent": {"sum": total},
            "isError": False,
        }
    return {
        "content": [{"type": "text", "text": f"unknown tool {name}"}],
        "isError": True,
    }


def respond(request_id: Any, result: Any) -> None:
    write({"jsonrpc": "2.0", "id": request_id, "result": result})


def error(request_id: Any, code: int, message: str) -> None:
    write({
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": code, "message": message},
    })


def write(message: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    raise SystemExit(main())
