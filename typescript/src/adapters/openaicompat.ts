import { AbortError, PraxoError } from "../errors";
import {
  Message,
  Request,
  Response as ModelResponse,
  ROLE_ASSISTANT,
  StreamingModel,
  ToolCall,
  Usage,
  messageToWire,
  usage,
} from "../model";

export interface OpenAIConfig {
  baseUrl: string;
  apiKey?: string;
  model?: string;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

export class OpenAICompatibleModel implements StreamingModel {
  constructor(private readonly config: OpenAIConfig) {}

  async generate(request: Request): Promise<ModelResponse> {
    return this.withSignal(request.signal, async (signal) => {
      const response = await this.post(request, false, signal);
      const data = (await response.json()) as Record<string, unknown>;
      return this.parseResponse(data);
    });
  }

  async generateStream(
    request: Request,
    onDelta: (delta: string) => void
  ): Promise<ModelResponse> {
    return this.withSignal(request.signal, async (signal) => {
      const response = await this.post(request, true, signal);
      if (!response.body) {
        throw new PraxoError("openaicompat: response has no stream body");
      }
      return this.readStream(response.body, onDelta);
    });
  }

  private async post(
    request: Request,
    stream: boolean,
    signal: AbortSignal
  ): Promise<Awaited<ReturnType<typeof fetch>>> {
    const response = await fetch(this.endpoint(), {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(this.payload(request, stream)),
      signal,
    });
    if (!response.ok) {
      const body = await response.text();
      throw new PraxoError(
        `openaicompat: HTTP ${response.status}: ${body.slice(0, 512)}`
      );
    }
    return response;
  }

  private async readStream(
    body: ReadableStream<Uint8Array>,
    onDelta: (delta: string) => void
  ): Promise<ModelResponse> {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    const content: string[] = [];
    const calls = new Map<
      number,
      { id: string; name: string; arguments: string }
    >();
    let finishReason: string | undefined;
    let total: Usage = usage();
    let finished = false;

    while (!finished) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let index = buffer.indexOf("\n");
      while (index >= 0) {
        const line = buffer.slice(0, index).trim();
        buffer = buffer.slice(index + 1);
        index = buffer.indexOf("\n");
        if (!line.startsWith("data:")) continue;
        const chunk = line.slice(5).trim();
        if (!chunk) continue;
        if (chunk === "[DONE]") {
          finished = true;
          index = -1;
          buffer = "";
          break;
        }
        const event = JSON.parse(chunk) as Record<string, unknown>;
        if (event.usage) total = parseUsage(event.usage);
        for (const choice of (event.choices as Record<string, unknown>[]) ?? []) {
          finishReason =
            (choice.finish_reason as string | undefined) ?? finishReason;
          const delta = (choice.delta as Record<string, unknown>) ?? {};
          const text = delta.content;
          if (typeof text === "string" && text) {
            content.push(text);
            onDelta(text);
          }
          for (const item of (delta.tool_calls as Record<string, unknown>[]) ?? []) {
            const callIndex = Number(item.index ?? 0);
            const slot = calls.get(callIndex) ?? {
              id: "",
              name: "",
              arguments: "",
            };
            if (item.id) slot.id = String(item.id);
            const fn = (item.function as Record<string, unknown>) ?? {};
            if (fn.name) slot.name += String(fn.name);
            if (fn.arguments) slot.arguments += String(fn.arguments);
            calls.set(callIndex, slot);
          }
        }
      }
    }
    const toolCalls: ToolCall[] = [...calls.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([index, slot]) => buildCall(index, slot));
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: content.join(""),
        toolCalls,
      },
      usage: total,
      finishReason,
    };
  }

  private parseResponse(data: Record<string, unknown>): ModelResponse {
    const choices = (data.choices as Record<string, unknown>[]) ?? [];
    if (!choices.length) {
      throw new PraxoError("openaicompat: response has no choices");
    }
    const choice = choices[0];
    const message = (choice.message as Record<string, unknown>) ?? {};
    const rawCalls = (message.tool_calls as Record<string, unknown>[]) ?? [];
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: String(message.content ?? ""),
        toolCalls: rawCalls.map((call, index) => buildCall(index, call)),
      },
      usage: parseUsage(data.usage),
      finishReason: choice.finish_reason as string | undefined,
    };
  }

  private payload(
    request: Request,
    stream: boolean
  ): Record<string, unknown> {
    const messages = request.messages.map((message: Message) => {
      const wire = messageToWire(message);
      if (wire.content === undefined && !wire.toolCalls) {
        wire.content = "";
      }
      return wire;
    });
    const payload: Record<string, unknown> = {
      model: request.model ?? this.config.model ?? "",
      messages,
      stream,
    };
    if (request.tools?.length) {
      payload.tools = request.tools.map((spec) => {
        const fn: Record<string, unknown> = {
          name: spec.name,
          description: spec.description,
        };
        if (spec.parameters !== undefined) fn.parameters = spec.parameters;
        return { type: "function", function: fn };
      });
    }
    if (request.toolChoice !== undefined) {
      payload.tool_choice = request.toolChoice;
    }
    if (request.responseFormat) {
      payload.response_format = {
        type: "json_schema",
        json_schema: {
          name: request.responseFormat.name ?? "output",
          schema: request.responseFormat.schema ?? {},
        },
      };
    }
    if (request.temperature) {
      payload.temperature = request.temperature;
    }
    return payload;
  }

  private endpoint(): string {
    return this.config.baseUrl.replace(/\/+$/, "") + "/chat/completions";
  }

  private headers(): Record<string, string> {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      Accept: "application/json",
    };
    if (this.config.apiKey) {
      headers.Authorization = `Bearer ${this.config.apiKey}`;
    }
    return { ...headers, ...(this.config.headers ?? {}) };
  }

  private async withSignal<T>(
    signal: AbortSignal | undefined,
    fn: (signal: AbortSignal) => Promise<T>
  ): Promise<T> {
    const controller = new AbortController();
    const timer = this.config.timeoutMs
      ? setTimeout(() => controller.abort(), this.config.timeoutMs)
      : undefined;
    const onAbort = (): void => controller.abort();
    signal?.addEventListener("abort", onAbort);
    try {
      if (signal?.aborted) throw new AbortError();
      return await fn(controller.signal);
    } catch (error) {
      if (controller.signal.aborted) throw new AbortError();
      throw error;
    } finally {
      if (timer) clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
    }
  }
}

function buildCall(
  index: number,
  raw: Record<string, unknown>
): ToolCall {
  const fn =
    (raw.function as Record<string, unknown> | undefined) ?? {
      name: raw.name,
      arguments: raw.arguments,
    };
  const argumentsText = String(fn.arguments ?? "{}");
  let args: Record<string, unknown>;
  try {
    const parsed = JSON.parse(argumentsText);
    args =
      parsed && typeof parsed === "object" && !Array.isArray(parsed)
        ? (parsed as Record<string, unknown>)
        : { content: parsed };
  } catch {
    args = { content: argumentsText };
  }
  return {
    id: String(raw.id ?? `call-${index}`),
    name: String(fn.name ?? ""),
    arguments: args,
  };
}

function parseUsage(raw: unknown): Usage {
  const value = (raw as Record<string, unknown>) ?? {};
  const details =
    (value.prompt_tokens_details as Record<string, unknown>) ?? {};
  return usage(
    Number(value.prompt_tokens ?? 0),
    Number(value.completion_tokens ?? 0),
    Number(details.cached_tokens ?? 0)
  );
}
