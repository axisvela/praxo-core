import { PraxoError } from "../errors";
import {
  Message,
  Request,
  Response as ModelResponse,
  ROLE_ASSISTANT,
  ROLE_SYSTEM,
  ROLE_TOOL,
  StreamingModel,
  TOOL_CHOICE_NONE,
  TOOL_CHOICE_REQUIRED,
  ToolCall,
  Usage,
  usage,
} from "../model";

export const GEMINI_DEFAULT_BASE_URL =
  "https://generativelanguage.googleapis.com";

export interface GeminiConfig {
  apiKey: string;
  model: string;
  baseUrl?: string;
  maxOutputTokens?: number;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

export class GeminiModel implements StreamingModel {
  constructor(private readonly config: GeminiConfig) {}

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
      throw new PraxoError("gemini: response has no stream body");
    }
    return this.readStream(response.body, onDelta);
  }

  private validate(): void {
    if (!this.config.apiKey) {
      throw new PraxoError("gemini: API key is required");
    }
    if (!this.config.model) {
      throw new PraxoError("gemini: model is required");
    }
  }

  private async post(
    request: Request,
    stream: boolean
  ): Promise<Awaited<ReturnType<typeof fetch>>> {
    const response = await fetch(this.endpoint(stream), {
      method: "POST",
      headers: this.headers(stream),
      body: JSON.stringify(this.payload(request)),
      signal: request.signal,
    });
    if (!response.ok) {
      const body = await response.text();
      throw new PraxoError(
        `gemini: HTTP ${response.status}: ${body.slice(0, 512)}`
      );
    }
    return response;
  }

  private payload(request: Request): Record<string, unknown> {
    const { system, contents } = buildContents(request.messages);
    const payload: Record<string, unknown> = { contents };
    if (system) payload.system_instruction = system;
    if (request.tools?.length) {
      payload.tools = [
        {
          functionDeclarations: request.tools.map((spec) => ({
            name: spec.name,
            description: spec.description,
            parameters: spec.parameters ?? {
              type: "object",
              properties: {},
            },
          })),
        },
      ];
      payload.toolConfig = {
        functionCallingConfig: {
          mode: toolMode(request.toolChoice),
        },
      };
    }
    if (request.temperature || this.config.maxOutputTokens) {
      payload.generationConfig = {
        temperature: request.temperature,
        maxOutputTokens: this.config.maxOutputTokens,
      };
    }
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
    const calls: ToolCall[] = [];
    let total: Usage = usage();
    let finishReason: string | undefined;

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
        if (!payload || payload === "[DONE]") continue;
        const chunk = JSON.parse(payload) as Record<string, unknown>;
        const error = chunk.error as Record<string, unknown> | undefined;
        if (error) {
          throw new PraxoError(
            `gemini: ${String(error.message ?? JSON.stringify(error))}`
          );
        }
        total = parseUsage(
          (chunk.usageMetadata as Record<string, unknown>) ?? {},
          total
        );
        const candidates = (chunk.candidates as Record<string, unknown>[]) ?? [];
        if (!candidates.length) continue;
        const candidate = candidates[0];
        finishReason =
          (candidate.finishReason as string | undefined) ?? finishReason;
        const parts =
          ((candidate.content as Record<string, unknown> | undefined)
            ?.parts as Record<string, unknown>[]) ?? [];
        for (const part of parts) {
          const text = part.text;
          if (typeof text === "string" && text) {
            content.push(text);
            onDelta(text);
          }
          const call = part.functionCall as Record<string, unknown> | undefined;
          if (call) {
            calls.push({
              id: `call-${calls.length + 1}`,
              name: String(call.name ?? ""),
              arguments: (call.args as Record<string, unknown>) ?? {},
            });
          }
        }
      }
    }
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: content.join(""),
        toolCalls: calls,
      },
      usage: total,
      finishReason,
    };
  }

  private endpoint(stream: boolean): string {
    const base = (this.config.baseUrl ?? GEMINI_DEFAULT_BASE_URL).replace(
      /\/+$/,
      ""
    );
    const model = encodeURIComponent(this.config.model);
    return stream
      ? `${base}/v1beta/models/${model}:streamGenerateContent?alt=sse`
      : `${base}/v1beta/models/${model}:generateContent`;
  }

  private headers(stream: boolean): Record<string, string> {
    return {
      "Content-Type": "application/json",
      Accept: stream ? "text/event-stream" : "application/json",
      "x-goog-api-key": this.config.apiKey,
      ...(this.config.headers ?? {}),
    };
  }

  private parseResponse(data: Record<string, unknown>): ModelResponse {
    const error = data.error as Record<string, unknown> | undefined;
    if (error) {
      throw new PraxoError(
        `gemini: ${String(error.message ?? JSON.stringify(error))}`
      );
    }
    const candidates = (data.candidates as Record<string, unknown>[]) ?? [];
    if (!candidates.length) {
      throw new PraxoError("gemini: empty response");
    }
    const candidate = candidates[0];
    const parts =
      ((candidate.content as Record<string, unknown> | undefined)
        ?.parts as Record<string, unknown>[]) ?? [];
    const { content, calls } = parseParts(parts);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content,
        toolCalls: calls,
      },
      usage: parseUsage(
        (data.usageMetadata as Record<string, unknown>) ?? {},
        usage()
      ),
      finishReason: candidate.finishReason as string | undefined,
    };
  }
}

function buildContents(messages: Message[]): {
  system: Record<string, unknown> | undefined;
  contents: Array<Record<string, unknown>>;
} {
  const systemParts: Record<string, unknown>[] = [];
  const contents: Array<Record<string, unknown>> = [];
  const toolParts: Record<string, unknown>[] = [];
  const names = new Map<string, string>();

  const flush = (): void => {
    if (toolParts.length) {
      contents.push({ role: "user", parts: [...toolParts] });
      toolParts.length = 0;
    }
  };

  for (const message of messages) {
    if (message.role === ROLE_SYSTEM) {
      if (message.content) systemParts.push({ text: message.content });
      continue;
    }
    if (message.role === ROLE_TOOL) {
      const name =
        names.get(message.toolId ?? "") ?? message.toolId ?? "tool";
      toolParts.push({
        functionResponse: {
          name,
          response: { result: message.content ?? "" },
        },
      });
      continue;
    }
    flush();
    const parts = messageParts(message);
    if (!parts.length) continue;
    contents.push({
      role: message.role === ROLE_ASSISTANT ? "model" : "user",
      parts,
    });
    for (const call of message.toolCalls ?? []) {
      if (call.id && call.name) names.set(call.id, call.name);
    }
  }
  flush();
  return {
    system: systemParts.length ? { parts: systemParts } : undefined,
    contents,
  };
}

function messageParts(message: Message): Record<string, unknown>[] {
  const parts: Record<string, unknown>[] = [];
  if (message.content) parts.push({ text: message.content });
  for (const block of message.contentBlocks ?? []) {
    if (block.type === "text" && block.text) parts.push({ text: block.text });
  }
  for (const call of message.toolCalls ?? []) {
    parts.push({
      functionCall: { name: call.name, args: call.arguments },
    });
  }
  return parts;
}

function toolMode(choice: string | undefined): string {
  if (choice === TOOL_CHOICE_REQUIRED) return "ANY";
  if (choice === TOOL_CHOICE_NONE) return "NONE";
  return "AUTO";
}

function parseParts(parts: Record<string, unknown>[]): {
  content: string;
  calls: ToolCall[];
} {
  const text: string[] = [];
  const calls: ToolCall[] = [];
  for (const part of parts) {
    if (typeof part.text === "string" && part.text) text.push(part.text);
    const call = part.functionCall as Record<string, unknown> | undefined;
    if (call) {
      calls.push({
        id: `call-${calls.length + 1}`,
        name: String(call.name ?? ""),
        arguments: (call.args as Record<string, unknown>) ?? {},
      });
    }
  }
  return { content: text.join(""), calls };
}

function parseUsage(
  raw: Record<string, unknown>,
  fallback: Usage
): Usage {
  if (!Object.keys(raw).length) return fallback;
  return usage(
    Number(raw.promptTokenCount ?? 0),
    Number(raw.candidatesTokenCount ?? 0),
    Number(raw.cachedContentTokenCount ?? 0)
  );
}
