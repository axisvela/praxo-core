from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import praxo
from praxo import Agent, AgentOptions, Message, Response, Session


class StaticModel:
    async def generate(self, request):
        del request
        return Response(message=Message(role="assistant", content="installed"))


async def main() -> None:
    assert praxo.__version__ == "0.2.1"
    assert praxo.SPEC_VERSION == "0.2.0"
    location = Path(praxo.__file__).resolve()
    assert "site-packages" in location.parts, location
    result = await Agent(AgentOptions(model=StaticModel())).run(
        Session(id="installed"), "hello"
    )
    assert result.output == "installed"
    assert result.steps == 1
    print(f"installed package smoke passed: {location}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except AssertionError as error:
        print(f"installed package smoke failed: {error}", file=sys.stderr)
        raise SystemExit(1)
