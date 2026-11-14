import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.checkpoint import Checkpoint, Message as CheckpointMessage
from praxo.model import Message, Request, Response


class TurnModel:
    async def generate(self, request: Request) -> Response:
        return Response(message=Message(role="assistant", content=f"turn {len(request.messages)}"))


class MemoryStore:
    def __init__(self) -> None:
        self._records: dict[str, Checkpoint] = {}

    def save(self, checkpoint: Checkpoint) -> None:
        self._records[checkpoint.session_id] = checkpoint

    def load(self, session_id: str) -> Checkpoint | None:
        return self._records.get(session_id)


def to_checkpoint(messages: list[Message]) -> list[CheckpointMessage]:
    return [CheckpointMessage(role=message.role, content=message.content or "") for message in messages]


def to_model(messages: list[CheckpointMessage]) -> list[Message]:
    return [Message(role=message.role, content=message.content) for message in messages]


async def run() -> None:
    store = MemoryStore()
    session = Session(
        id="session-1",
        messages=[
            Message(role="user", content="first"),
            Message(role="assistant", content="ack"),
        ],
    )
    store.save(Checkpoint(
        id="cp-1",
        session_id=session.id,
        run_id="run-1",
        status="completed",
        messages=to_checkpoint(session.messages),
    ))

    agent = Agent(AgentOptions(model=TurnModel(), max_steps=2))
    loaded = store.load(session.id)
    if loaded is None:
        raise RuntimeError("checkpoint not found")
    session.messages = to_model(loaded.messages)
    result = await agent.run(session, "second")
    if result.output != "turn 3":
        raise RuntimeError(f"unexpected second turn: {result.output!r}")

    session.messages.append(Message(role="user", content="second"))
    session.messages.append(Message(role="assistant", content=result.output))
    store.save(Checkpoint(
        id="cp-2",
        session_id=session.id,
        run_id="run-2",
        status="completed",
        messages=to_checkpoint(session.messages),
    ))

    loaded = store.load(session.id)
    if loaded is None:
        raise RuntimeError("checkpoint not found")
    session.messages = to_model(loaded.messages)
    result = await agent.run(session, "third")
    if result.output != "turn 5":
        raise RuntimeError(f"unexpected third turn: {result.output!r}")

    print(f"restored messages: {len(loaded.messages)}")
    print(f"output: {result.output}")


if __name__ == "__main__":
    asyncio.run(run())
