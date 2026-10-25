import { ToolNotSelectedError } from "../errors";
import {
  Message,
  Model,
  Request,
  ROLE_SYSTEM,
  ROLE_USER,
  ToolSpec,
} from "../model";
import {
  MaybePromise,
  Middleware,
  MiddlewareToolCall,
  ModelCall,
} from "./base";
import { extractJson } from "./structured";

export const DEFAULT_TOOL_SELECTOR_PROMPT =
  "Select the tools needed to answer the user query.\n" +
  'Return only JSON in the form {"tools":["tool_name"]}.\n' +
  "Prefer the smallest sufficient set. Return {\"tools\":[]} when no " +
  "tool is needed.";

export interface ToolSelector {
  select(
    query: string,
    tools: ToolSpec[]
  ): MaybePromise<string[]>;
}

export function toolSelectionMiddleware(
  selector: ToolSelector | null
): Middleware {
  const selected = new Map<string, Set<string>>();

  return {
    name: "tool-selection",
    async beforeModel(call: ModelCall): Promise<void> {
      if (!call.request || !selector) return;
      const names = await selector.select(
        lastUserMessage(call.request.messages),
        call.request.tools ?? []
      );
      const chosen = new Set(names ?? []);
      selected.set(call.runId, chosen);
      call.request.tools = (call.request.tools ?? []).filter((spec) =>
        chosen.has(spec.name)
      );
    },
    beforeTool(call: MiddlewareToolCall): void {
      const chosen = selected.get(call.runId);
      if (!chosen) return;
      if (!chosen.has(call.call.name)) {
        throw new ToolNotSelectedError();
      }
    },
    afterRun(result: unknown): void {
      const runId = (result as { runId?: string } | undefined)?.runId;
      if (runId) selected.delete(runId);
    },
  };
}

export function lastUserMessage(messages: Message[]): string {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    if (messages[index].role === ROLE_USER) {
      return messages[index].content ?? "";
    }
  }
  return "";
}

export class ModelToolSelector implements ToolSelector {
  constructor(
    private readonly model: Model | null,
    private readonly prompt = "",
    private readonly maxTools = 0
  ) {}

  async select(query: string, tools: ToolSpec[]): Promise<string[]> {
    if (!this.model) {
      throw new Error("agent: tool selector model is required");
    }
    if (!tools.length) return [];
    const prompt = this.prompt.trim() || DEFAULT_TOOL_SELECTOR_PROMPT;
    const catalog = tools
      .map((spec) => `\n- ${spec.name}: ${spec.description}`)
      .join("");
    const request: Request = {
      messages: [
        { role: ROLE_SYSTEM, content: prompt },
        {
          role: ROLE_USER,
          content: `Query: ${query}\nAvailable tools:${catalog}`,
        },
      ],
    };
    const response = await this.model.generate(request);
    let parsed: unknown;
    try {
      parsed = extractJson(response.message.content ?? "");
    } catch (error) {
      throw new Error(
        `agent: tool selector response: ${String(error)}`
      );
    }
    const requested = (parsed as { tools?: unknown }).tools;
    if (!Array.isArray(requested)) return [];
    const known = new Set(tools.map((spec) => spec.name));
    const seen = new Set<string>();
    const out: string[] = [];
    for (const name of requested) {
      if (typeof name !== "string") continue;
      if (!known.has(name) || seen.has(name)) continue;
      seen.add(name);
      out.push(name);
      if (this.maxTools > 0 && out.length >= this.maxTools) break;
    }
    return out;
  }
}
