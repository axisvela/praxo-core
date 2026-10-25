import { Model, Request, Response } from "../model";
import { ModelHandler, ModelMiddleware } from "./base";

export function fallbackModel(
  fallback: Model | null
): ModelMiddleware {
  return (next: ModelHandler): ModelHandler => {
    return async (request: Request): Promise<Response> => {
      try {
        return await next(request);
      } catch (primaryError) {
        if (!fallback) throw primaryError;
        try {
          return await fallback.generate(request);
        } catch (fallbackError) {
          throw new AggregateError(
            [primaryError, fallbackError],
            "primary and fallback model both failed"
          );
        }
      }
    };
  };
}
