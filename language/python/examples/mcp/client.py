import asyncio
import sys
from pathlib import Path

from praxo.adapters.mcp import MCPClient, MCPServerConfig
from praxo.tool import Registry


def server_config() -> MCPServerConfig:
    return MCPServerConfig(
        command=sys.executable,
        args=["-u", str(Path(__file__).with_name("server.py"))],
    )


async def demo() -> str:
    async with MCPClient(server_config(), timeout=5.0) as client:
        tools = await client.list_tools()
        registry = Registry()
        await client.register_tools(registry)
        result = await client.call_tool("add", {"a": 2, "b": 3})
        return f"tools={','.join(tool.name for tool in tools)}; sum={result['sum']}"


def main() -> None:
    print(asyncio.run(demo()))


if __name__ == "__main__":
    main()
