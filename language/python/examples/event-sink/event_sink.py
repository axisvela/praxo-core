import asyncio
from typing import Any

from praxo.agent import Agent, AgentOptions, Session
from praxo.event import Event, FilterSink, MultiSink, Sink
from praxo.tool import FuncTool, Registry


class RecordingSink:
    def __init__(self) -> None:
        self.events: list[Event] = []

    async def emit(self, event: Event) -> None:
        self.events.append(event)

    def types(self) -> list[str]:
        return [event.type for event in self.events]


def create_agent(model, all_sink: Sink, tool_sink: Sink) -> Agent:
    tools = Registry()
    tools.register(
        FuncTool(
            "lookup",
            "Look up a small status value.",
            lambda args: {"key": args.get("key", ""), "value": "green"},
        )
    )
    events = MultiSink(
        [
            all_sink,
            FilterSink(tool_sink, lambda event: event.type == "tool.call"),
        ]
    )
    return Agent(
        AgentOptions(
            model=model,
            tools=tools,
            events=events,
            system_prompt="Use tools when asked for status.",
            max_steps=3,
        )
    )


async def run(
    model,
    all_sink: Sink,
    tool_sink: Sink,
    prompt: str = "Check the status.",
) -> str:
    result = await create_agent(model, all_sink, tool_sink).run(
        Session(id="event-sink"),
        prompt,
    )
    return result.output


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; wire a real model in event_sink.py."
    )
