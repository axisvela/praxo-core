import {
  ModelCall,
  MiddlewareToolCall,
  PIIRedactor,
  Request,
  Response,
  ROLE_ASSISTANT,
  RunState,
  StructuredOutput,
  StructuredOutputError,
  ToolCall,
  ToolResult,
  ToolSpec,
  callLimitMiddleware,
  defaultPiiRules,
  fallbackModel,
  piiMiddleware,
  toolSelectionMiddleware,
} from "../index";
import type { Vector } from "./run";

export async function runMiddleware(vector: Vector): Promise<void> {
  const input = vector.input;
  const exp = vector.expect;
  switch (input.operation) {
    case "pii": {
      const got = new PIIRedactor(defaultPiiRules()).redact(
        String(input.text ?? "")
      );
      check(got === exp.text, `text: got ${JSON.stringify(got)}`);
      return;
    }
    case "pii-value": {
      const middleware = piiMiddleware(
        new PIIRedactor(defaultPiiRules())
      );
      const result: ToolResult = { value: input.value };
      await middleware.afterTool?.(
        toolCall("r1", "s1", "echo"),
        result
      );
      check(
        JSON.stringify(result.value) === JSON.stringify(exp.value),
        `value: got ${JSON.stringify(result.value)}`
      );
      return;
    }
    case "structured": {
      const structured = new StructuredOutput({
        schema: (input.schema as Record<string, unknown>) ?? {},
        maxRepairs: Number(input.maxRepairs ?? 0),
        repair: input.repairOutput
          ? () => String(input.repairOutput)
          : undefined,
      });
      const result = { output: String(input.output ?? "") };
      try {
        await structured.apply(result);
      } catch (error) {
        if (exp.ok) throw error;
        check(
          error instanceof StructuredOutputError &&
            error.code === exp.errorCode,
          `errorCode: got ${String((error as { code?: string }).code)}`
        );
        return;
      }
      check(Boolean(exp.ok), "expected a structured output error");
      check(
        result.output === exp.output,
        `output: got ${JSON.stringify(result.output)}`
      );
      return;
    }
    case "call-limit": {
      const middleware = callLimitMiddleware(
        Number(input.modelLimit ?? 0),
        Number(input.toolLimit ?? 0)
      );
      middleware.beforeRun?.({ runId: "r1" } as RunState);
      const outcomes: string[] = [];
      for (const kind of (input.calls as string[]) ?? []) {
        try {
          if (kind === "model") {
            middleware.beforeModel?.({
              runId: "r1",
              sessionId: "s1",
              request: { messages: [] },
            });
          } else if (kind === "tool") {
            middleware.beforeTool?.(toolCall("r1", "s1", "echo"));
          } else {
            throw new Error(`unknown call kind ${JSON.stringify(kind)}`);
          }
          outcomes.push("ok");
        } catch (error) {
          outcomes.push((error as { code?: string }).code ?? "ERROR");
        }
      }
      check(
        JSON.stringify(outcomes) === JSON.stringify(exp.outcomes ?? []),
        `outcomes: got ${JSON.stringify(outcomes)}`
      );
      return;
    }
    case "tool-selection": {
      const names = (input.selected as string[]) ?? [];
      const middleware = toolSelectionMiddleware({
        select: async () => names,
      });
      const tools: ToolSpec[] = ((input.tools as string[]) ?? []).map(
        (name) => ({ name, description: "" })
      );
      const call: ModelCall = {
        runId: "r1",
        sessionId: "s1",
        request: { messages: [], tools },
      };
      await middleware.beforeModel?.(call);
      const advertised = (call.request.tools ?? []).map((spec) => spec.name);
      check(
        JSON.stringify(advertised) === JSON.stringify(exp.advertised ?? []),
        `advertised: got ${JSON.stringify(advertised)}`
      );
      let reject = "ok";
      try {
        await middleware.beforeTool?.(
          toolCall("r1", "s1", String(input.requested ?? ""))
        );
      } catch (error) {
        reject = (error as { code?: string }).code ?? "ERROR";
      }
      check(reject === exp.reject, `reject: got ${JSON.stringify(reject)}`);
      return;
    }
    case "fallback": {
      const fallback = {
        async generate(): Promise<Response> {
          return {
            message: {
              role: ROLE_ASSISTANT,
              content: String(input.fallbackContent ?? ""),
            },
          };
        },
      };
      const handler = fallbackModel(fallback)(async () => {
        throw new Error("primary failed");
      });
      const response = await handler({ messages: [] });
      check(
        response.message.content === exp.output,
        `output: got ${JSON.stringify(response.message.content)}`
      );
      return;
    }
    default:
      throw new Error(
        `unknown middleware operation ${JSON.stringify(input.operation)}`
      );
  }
}

function toolCall(
  runId: string,
  sessionId: string,
  name: string
): MiddlewareToolCall {
  const call: ToolCall = { id: "c", name, arguments: {} };
  return { runId, sessionId, call };
}

function check(condition: boolean, detail: string): void {
  if (!condition) throw new Error(detail);
}
