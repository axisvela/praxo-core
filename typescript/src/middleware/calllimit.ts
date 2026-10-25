import {
  ModelCallLimitError,
  ToolCallLimitError,
} from "../errors";
import {
  Middleware,
  MiddlewareToolCall,
  ModelCall,
  RunState,
} from "./base";

interface Count {
  models: number;
  tools: number;
}

export function callLimitMiddleware(
  modelLimit: number,
  toolLimit: number
): Middleware {
  const counts = new Map<string, Count>();

  return {
    name: "call-limit",
    beforeRun(state: RunState): void {
      counts.set(state.runId, { models: 0, tools: 0 });
    },
    beforeModel(call: ModelCall): void {
      const count =
        counts.get(call.runId) ?? { models: 0, tools: 0 };
      counts.set(call.runId, count);
      count.models += 1;
      if (modelLimit > 0 && count.models > modelLimit) {
        throw new ModelCallLimitError();
      }
    },
    beforeTool(call: MiddlewareToolCall): void {
      const count =
        counts.get(call.runId) ?? { models: 0, tools: 0 };
      counts.set(call.runId, count);
      count.tools += 1;
      if (toolLimit > 0 && count.tools > toolLimit) {
        throw new ToolCallLimitError();
      }
    },
    afterRun(result: unknown): void {
      const runId = (result as { runId?: string } | undefined)?.runId;
      if (runId) counts.delete(runId);
    },
  };
}
