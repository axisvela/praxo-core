import asyncio
from typing import Any, Callable

from praxo.agent import Agent, AgentOptions, Session
from praxo.model import Message, Response


class StreamingModel:
    def __init__(self, chunks: list[str]) -> None:
        self.chunks = chunks

    async def generate(self, request):
        return Response(message=Message(role="assistant", content="".join(self.chunks)))

    async def generate_stream(self, request, on_delta: Callable[[str], Any]) -> Response:
        for chunk in self.chunks:
            on_delta(chunk)
        return await self.generate(request)


async def run(model, on_delta, prompt: str = "Check the status.") -> str:
    agent = Agent(
        AgentOptions(
            model=model,
            on_delta=on_delta,
            system_prompt="Answer with the current status.",
            max_steps=2,
        )
    )
    result = await agent.run(Session(id="streaming"), prompt)
    return result.output


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; wire a real streaming model in streaming.py."
    )
