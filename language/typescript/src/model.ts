export const ROLE_SYSTEM = "system";
export const ROLE_USER = "user";
export const ROLE_ASSISTANT = "assistant";
export const ROLE_TOOL = "tool";

export const TOOL_CHOICE_AUTO = "auto";
export const TOOL_CHOICE_NONE = "none";
export const TOOL_CHOICE_REQUIRED = "required";

export interface ContentBlock {
  type: string;
  text?: string;
  imageUrl?: string;
  data?: string;
}

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface Message {
  role: string;
  content?: string;
  contentBlocks?: ContentBlock[];
  toolCalls?: ToolCall[];
  toolId?: string;
}

export interface ToolSpec {
  name: string;
  description: string;
  parameters?: Record<string, unknown>;
  risk?: string;
}

export interface ResponseFormat {
  name?: string;
  schema?: Record<string, unknown>;
}

export interface CacheHint {
  stablePrefix?: number;
  ttl?: string;
}

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  cachedTokens?: number;
}

export interface Request {
  model?: string;
  messages: Message[];
  tools?: ToolSpec[];
  toolChoice?: string;
  responseFormat?: ResponseFormat;
  cacheHint?: CacheHint;
  temperature?: number;
  signal?: AbortSignal;
}

export interface Response {
  message: Message;
  usage?: Usage;
  finishReason?: string;
}

export interface Model {
  generate(request: Request): Promise<Response>;
}

export interface StreamingModel extends Model {
  generateStream(
    request: Request,
    onDelta: (delta: string) => void
  ): Promise<Response>;
}

export function usage(
  inputTokens = 0,
  outputTokens = 0,
  cachedTokens = 0
): Usage {
  return { inputTokens, outputTokens, cachedTokens };
}

export function contentBlockToWire(
  block: ContentBlock
): Record<string, unknown> {
  const out: Record<string, unknown> = { type: block.type };
  if (block.text !== undefined) out.text = block.text;
  if (block.imageUrl !== undefined) out.image_url = block.imageUrl;
  if (block.data !== undefined) out.data = block.data;
  return out;
}

export function contentBlockFromWire(raw: Record<string, unknown>): ContentBlock {
  return {
    type: String(raw.type ?? ""),
    text: raw.text as string | undefined,
    imageUrl: raw.image_url as string | undefined,
    data: raw.data as string | undefined,
  };
}

export function toolCallToWire(call: ToolCall): Record<string, unknown> {
  return { id: call.id, name: call.name, arguments: call.arguments };
}

export function toolCallFromWire(raw: Record<string, unknown>): ToolCall {
  return {
    id: String(raw.id ?? ""),
    name: String(raw.name ?? ""),
    arguments: (raw.arguments as Record<string, unknown>) ?? {},
  };
}

export function messageToWire(message: Message): Record<string, unknown> {
  const out: Record<string, unknown> = { role: message.role };
  if (message.content) out.content = message.content;
  if (message.contentBlocks?.length) {
    out.contentBlocks = message.contentBlocks.map(contentBlockToWire);
  }
  if (message.toolCalls?.length) {
    out.toolCalls = message.toolCalls.map(toolCallToWire);
  }
  if (message.toolId !== undefined) out.toolId = message.toolId;
  return out;
}

export function messageFromWire(raw: Record<string, unknown>): Message {
  const blocks = (raw.contentBlocks as Record<string, unknown>[]) ?? [];
  const calls = (raw.toolCalls as Record<string, unknown>[]) ?? [];
  return {
    role: String(raw.role ?? ""),
    content: raw.content as string | undefined,
    contentBlocks: blocks.map(contentBlockFromWire),
    toolCalls: calls.map(toolCallFromWire),
    toolId: raw.toolId as string | undefined,
  };
}

export function toolSpecToWire(spec: ToolSpec): Record<string, unknown> {
  const out: Record<string, unknown> = {
    name: spec.name,
    description: spec.description,
  };
  if (spec.parameters !== undefined) out.parameters = spec.parameters;
  if (spec.risk !== undefined) out.risk = spec.risk;
  return out;
}
