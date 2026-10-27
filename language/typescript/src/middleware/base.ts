import { Request, Response, ToolCall } from "../model";

export interface RunState {
  runId: string;
  session?: unknown;
  prompt?: string;
}

export interface ModelCall {
  runId: string;
  sessionId: string;
  request: Request;
  skip?: boolean;
  response?: Response;
}

export interface MiddlewareToolCall {
  runId: string;
  sessionId: string;
  call: ToolCall;
  skip?: boolean;
  result?: unknown;
  error?: unknown;
}

export interface ToolResult {
  value?: unknown;
  error?: unknown;
}

export type MaybePromise<T> = T | Promise<T>;

export interface Middleware {
  name?: string;
  beforeRun?: (state: RunState) => MaybePromise<void>;
  beforeModel?: (call: ModelCall) => MaybePromise<void>;
  afterModel?: (
    call: ModelCall,
    response: Response
  ) => MaybePromise<void>;
  beforeTool?: (call: MiddlewareToolCall) => MaybePromise<void>;
  afterTool?: (
    call: MiddlewareToolCall,
    result: ToolResult
  ) => MaybePromise<void>;
  afterRun?: (
    result: unknown,
    error: unknown
  ) => MaybePromise<void>;
}

export type ModelHandler = (request: Request) => Promise<Response>;
export type ModelMiddleware = (next: ModelHandler) => ModelHandler;

export async function maybeAwait<T>(value: MaybePromise<T>): Promise<T> {
  return await value;
}

export function mergeMiddleware(items: Middleware[]): Middleware[] {
  const out: Middleware[] = [];
  const index = new Map<string, number>();
  for (const item of items) {
    if (!item.name) {
      out.push(item);
      continue;
    }
    const current = index.get(item.name);
    if (current !== undefined) {
      out[current] = item;
      continue;
    }
    index.set(item.name, out.length);
    out.push(item);
  }
  return out;
}
