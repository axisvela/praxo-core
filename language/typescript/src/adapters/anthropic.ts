import { PraxoError } from "../errors";
import {
  Message,
  Request,
  Response as ModelResponse,
  ROLE_ASSISTANT,
  ROLE_SYSTEM,
  ROLE_TOOL,
  StreamingModel,
  TOOL_CHOICE_AUTO,
  TOOL_CHOICE_NONE,
  TOOL_CHOICE_REQUIRED,
  ToolCall,
  Usage,
  usage,
} from "../model";

export const ANTHROPIC_DEFAULT_BASE_URL = "https://api.anthropic.com";
export const ANTHROPIC_DEFAULT_VERSION = "2023-06-01";
export const ANTHROPIC_DEFAULT_MAX_TOKENS = 1024;

export interface AnthropicConfig {
  apiKey: string;
  model: string;
  baseUrl?: string;
  version?: string;
  maxTokens?: number;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

type WireContent = Record<string, unknown>;

export class AnthropicModel implements StreamingModel {
  constructor(private readonly config: AnthropicConfig) {}

  async generate(request: Request): Promise<ModelResponse> {
    this.validate();
    const response = await this.post(request, false);
    const data = (await response.json()) as Record<string, unknown>;
    return this.parseResponse(data);
  }

  async generateStream(
    request: Request,
    onDelta: (delta: string) => void
  ): Promise<ModelResponse> {
    this.validate();
    const response = await this.post(request, true);
    if (!response.body) {
      throw new PraxoError("anthropic: response has no stream body");
    }
    return this.readStream(response.body, onDelta);
  }

  private validate(): void {
    if (!this.config.apiKey) {
      throw new PraxoError("anthropic: API key is required");
    }
    if (!this.config.model) {
      throw new PraxoError("anthropic: model is required");
    }
  }

  private async post(
    request: Request,
    stream: boolean
  ): Promise<Awaited<ReturnType<typeof fetch>>> {
    const response = await fetch(this.endpoint(), {
      method: "POST",
      headers: this.headers(stream),
      body: JSON.stringify(this.payload(request, stream)),
      signal: request.signal,
    });
    if (!response.ok) {
      const body = await response.text();
      throw new PraxoError(
        `anthropic: HTTP ${response.status}: ${body.slice(0, 512)}`
      );
    }
    return response;
  }

  private payload(request: Request, stream: boolean): Record<string, unknown> {
    const { system, messages } = buildMessages(request.messages);
    const payload: Record<string, unknown> = {
      model: request.model ?? this.config.model,
      max_tokens: this.config.maxTokens ?? ANTHROPIC_DEFAULT_MAX_TOKENS,
      messages,
      stream,
    };
    if (system) payload.system = system;
    if (request.tools?.length) {
      payload.tools = request.tools.map((spec) => ({
        name: spec.name,
        description: spec.description,
        input_schema: spec.parameters ?? {
          type: "object",
          properties: {},
        },
      }));
      const choice = toolChoice(request.toolChoice);
      if (choice) payload.tool_choice = choice;
    }
    if (request.temperature) payload.temperature = request.temperature;
    return payload;
  }

  private async readStream(
    body: ReadableStream<Uint8Array>,
    onDelta: (delta: string) => void
  ): Promise<ModelResponse> {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    const content: string[] = [];
    const blocks = new Map<number, Record<string, unknown>>();
    let inputTokens = 0;
    let outputTokens = 0;
    let cachedTokens = 0;
    let stopReason: string | undefined;
    let stopped = false;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const raw of lines) {
        const line = raw.trim();
        if (!line.startsWith("data:")) continue;
        const payload = line.slice(5).trim();
        if (!payload) continue;
        const event = JSON.parse(payload) as Record<string, unknown>;
        const type = String(event.type ?? "");
        if (type === "message_start") {
          const message = event.message as Record<string, unknown> | undefined;
          const stats = (message?.usage ?? {}) as Record<string, unknown>;
          inputTokens = Number(stats.input_tokens ?? 0);
          cachedTokens = Number(stats.cache_read_input_tokens ?? 0);
        } else if (type === "content_block_start") {
          const index = Number(event.index ?? 0);
          const block = (event.content_block ?? {}) as Record<string, unknown>;
          blocks.set(index, {
            type: String(block.type ?? ""),
            id: String(block.id ?? ""),
            name: String(block.name ?? ""),
            input: block.input ?? {},
            arguments: "",
          });
          if (typeof block.text === "string" && block.text) {
            content.push(block.text);
            onDelta(block.text);
          }
        } else if (type === "content_block_delta") {
          const index = Number(event.index ?? 0);
          const block =
            blocks.get(index) ??
            { type: "", id: "", name: "", input: {}, arguments: "" };
          blocks.set(index, block);
          const delta = (event.delta ?? {}) as Record<string, unknown>;
          if (delta.type === "text_delta") {
            const text = String(delta.text ?? "");
            if (text) {
              content.push(text);
              onDelta(text);
            }
          } else if (delta.type === "input_json_delta") {
            block.arguments = String(block.arguments ?? "") +
              String(delta.partial_json ?? "");
          }
        } else if (type === "message_delta") {
          const delta = (event.delta ?? {}) as Record<string, unknown>;
          stopReason = (delta.stop_reason as string | undefined) ?? stopReason;
          const stats = (event.usage ?? {}) as Record<string, unknown>;
          outputTokens = Number(stats.output_tokens ?? 0);
          if (stats.input_tokens) inputTokens = Number(stats.input_tokens);
        } else if (type === "message_stop") {
          stopped = true;
          break;
        } else if (type === "error") {
          const error = (event.error ?? {}) as Record<string, unknown>;
          throw new PraxoError(
            `anthropic: ${String(error.message ?? "stream error")}`
          );
        }
      }
      if (stopped) break;
    }
    if (!stopped) {
      throw new PraxoError("anthropic: stream ended before completion");
    }
    const calls: ToolCall[] = [];
    for (const index of [...blocks.keys()].sort((a, b) => a - b)) {
      const block = blocks.get(index)!;
      if (block.type !== "tool_use") continue;
      let args = block.input as Record<string, unknown>;
      const raw = String(block.arguments ?? "");
      if (raw) {
        try {
          args = JSON.parse(raw) as Record<string, unknown>;
        } catch (error) {
          throw new PraxoError(
            `anthropic: tool ${String(block.name)} arguments: ${String(error)}`
          );
        }
      }
      calls.push({
        id: String(block.id || `call-${calls.length + 1}`),
        name: String(block.name ?? ""),
        arguments: args ?? {},
      });
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: content.join(""),
        toolCalls: calls,
      },
      usage: usage(inputTokens, outputTokens, cachedTokens),
      finishReason: stopReason,
    };
  }

  private endpoint(): string {
    return `${(this.config.baseUrl ?? ANTHROPIC_DEFAULT_BASE_URL).replace(
      /\/+$/,
      ""
    )}/v1/messages`;
  }

  private headers(stream: boolean): Record<string, string> {
    return {
      "Content-Type": "application/json",
      Accept: stream ? "text/event-stream" : "application/json",
      "x-api-key": this.config.apiKey,
      "anthropic-version":
        this.config.version ?? ANTHROPIC_DEFAULT_VERSION,
      ...(this.config.headers ?? {}),
    };
  }

  private parseResponse(data: Record<string, unknown>): ModelResponse {
    const error = data.error as Record<string, unknown> | undefined;
    if (error) {
      throw new PraxoError(
        `anthropic: ${String(error.message ?? JSON.stringify(error))}`
      );
    }
    const { content, calls } = parseContent(
      (data.content as WireContent[]) ?? []
    );
    const stats = (data.usage ?? {}) as Record<string, unknown>;
    return {
      message: {
        role: ROLE_ASSISTANT,
        content,
        toolCalls: calls,
      },
      usage: usage(
        Number(stats.input_tokens ?? 0),
        Number(stats.output_tokens ?? 0),
        Number(stats.cache_read_input_tokens ?? 0)
      ),
      finishReason: data.stop_reason as string | undefined,
    };
  }
}

function buildMessages(messages: Message[]): {
  system: string;
  messages: Array<Record<string, unknown>>;
} {
  const system: string[] = [];
  const out: Array<Record<string, unknown>> = [];
  const toolResults: WireContent[] = [];

  const flush = (): void => {
    if (toolResults.length) {
      out.push({ role: "user", content: [...toolResults] });
      toolResults.length = 0;
    }
  };

  for (const message of messages) {
    if (message.role === ROLE_SYSTEM) {
      if (message.content) system.push(message.content);
      continue;
    }
    if (message.role === ROLE_TOOL) {
      toolResults.push({
        type: "tool_result",
        tool_use_id: message.toolId ?? "",
        content: message.content ?? "",
      });
      continue;
    }
    flush();
    const content = messageContent(message);
    if (content.length) out.push({ role: message.role, content });
  }
  flush();
  return { system: system.join("\n\n"), messages: out };
}

function messageContent(message: Message): WireContent[] {
  const content: WireContent[] = [];
  if (message.content) content.push({ type: "text", text: message.content });
  for (const block of message.contentBlocks ?? []) {
    if (block.type === "text" && block.text) {
      content.push({ type: "text", text: block.text });
    }
  }
  for (const call of message.toolCalls ?? []) {
    content.push({
      type: "tool_use",
      id: call.id,
      name: call.name,
      input: call.arguments,
    });
  }
  return content;
}

function toolChoice(
  choice: string | undefined
): Record<string, string> | undefined {
  if (choice === TOOL_CHOICE_AUTO) return { type: "auto" };
  if (choice === TOOL_CHOICE_REQUIRED) return { type: "any" };
  if (choice === TOOL_CHOICE_NONE) return { type: "none" };
  return undefined;
}

function parseContent(blocks: WireContent[]): {
  content: string;
  calls: ToolCall[];
} {
  const text: string[] = [];
  const calls: ToolCall[] = [];
  for (const block of blocks) {
    if (block.type === "text") {
      text.push(String(block.text ?? ""));
    } else if (block.type === "tool_use") {
      calls.push({
        id: String(block.id || `call-${calls.length + 1}`),
        name: String(block.name ?? ""),
        arguments: (block.input as Record<string, unknown>) ?? {},
      });
    }
  }
  return { content: text.join(""), calls };
}
