from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable, Protocol, runtime_checkable

from .errors import ToolNotFoundError
from .model import ToolSpec


@runtime_checkable
class Tool(Protocol):
    name: str
    description: str

    async def invoke(self, args: dict[str, Any]) -> Any: ...


class FuncTool:
    def __init__(
        self,
        name: str,
        description: str,
        fn: Callable[[dict[str, Any]], Awaitable[Any] | Any],
    ) -> None:
        self.name = name
        self.description = description
        self.fn = fn

    async def invoke(self, args: dict[str, Any]) -> Any:
        result = self.fn(args)
        if hasattr(result, "__await__"):
            return await result
        return result


@dataclass
class GatewayInfo:
    name: str
    description: str = ""
    risk: str = ""


@runtime_checkable
class Gateway(Protocol):
    async def execute(
        self, name: str, input: dict[str, Any], token: str = ""
    ) -> Any: ...

    def list_tools(self) -> list[GatewayInfo]: ...


class GatewayTool:
    def __init__(self, gateway: Gateway, info: GatewayInfo) -> None:
        self.gateway = gateway
        self.info = info
        self.name = info.name
        self.description = info.description

    async def invoke(self, args: dict[str, Any]) -> Any:
        return await self.gateway.execute(self.info.name, args)


def new_gateway_tools(gateway: Gateway) -> list[Tool]:
    if gateway is None:
        return []
    return [
        GatewayTool(gateway, info)
        for info in sorted(gateway.list_tools(), key=lambda item: item.name)
    ]


@dataclass
class Registry:
    _tools: dict[str, Tool] = field(default_factory=dict)

    def register(self, tool: Tool) -> None:
        self._tools[tool.name] = tool

    def get(self, name: str) -> Tool:
        try:
            return self._tools[name]
        except KeyError as exc:
            raise ToolNotFoundError(f"tool not found: {name}") from exc

    def specs(self) -> list[ToolSpec]:
        return [
            ToolSpec(name=tool.name, description=tool.description)
            for tool in sorted(self._tools.values(), key=lambda item: item.name)
        ]

    def __len__(self) -> int:
        return len(self._tools)
