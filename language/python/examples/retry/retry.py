import asyncio
from typing import Callable

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PraxoError
from praxo.middleware import ModelHandler, ModelMiddleware
from praxo.model import Message, Response

RETRYABLE = {"MODEL_UNAVAILABLE"}


class ModelUnavailableError(PraxoError):
    code = "MODEL_UNAVAILABLE"


def retry_model(max_attempts: int = 3) -> ModelMiddleware:
    def middleware(next_handler: ModelHandler) -> ModelHandler:
        async def handler(request):
            last_error: PraxoError | None = None
            for attempt in range(1, max_attempts + 1):
                try:
                    return await next_handler(request)
                except PraxoError as error:
                    last_error = error
                    if error.code not in RETRYABLE or attempt == max_attempts:
                        raise
            raise last_error or ModelUnavailableError("model unavailable")

        return handler

    return middleware


async def run(
    model,
    max_attempts: int = 3,
    prompt: str = "Check the status.",
) -> str:
    agent = Agent(
        AgentOptions(
            model=model,
            model_middleware=[retry_model(max_attempts)],
            max_steps=2,
        )
    )
    result = await agent.run(Session(id="retry"), prompt)
    return result.output


class FlakyModel:
    def __init__(self, failures: int) -> None:
        self.failures = failures
        self.calls = 0

    async def generate(self, request):
        self.calls += 1
        if self.calls <= self.failures:
            raise ModelUnavailableError("temporary outage")
        return Response(message=Message(role="assistant", content="status: green"))


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; wire a real provider in retry.py."
    )
