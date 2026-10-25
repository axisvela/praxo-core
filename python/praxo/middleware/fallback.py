from __future__ import annotations

from ..model import Model, Request, Response
from .base import ModelHandler, ModelMiddleware


def fallback_model(fallback: Model | None) -> ModelMiddleware:
    def wrap(next_handler: ModelHandler) -> ModelHandler:
        async def handler(request: Request) -> Response:
            try:
                return await next_handler(request)
            except Exception as primary_error:
                if fallback is None:
                    raise
                try:
                    return await fallback.generate(request)
                except Exception as fallback_error:
                    raise fallback_error from primary_error

        return handler

    return wrap
