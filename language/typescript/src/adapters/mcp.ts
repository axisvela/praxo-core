import {
  McpCancelledError,
  McpError,
  McpProtocolError,
  McpTimeoutError,
  McpToolError,
  McpTransportError,
} from "../errors";
import { ToolSpec } from "../model";
import { Registry, Tool } from "../tool";
import { McpStdioTransport } from "./mcp-transport";
import type { McpTransport } from "./mcp-transport";

export type { McpTransport } from "./mcp-transport";

const DEFAULT_PROTOCOL_VERSION = "2024-11-05";
const DEFAULT_TIMEOUT_MS = 30000;
const CLIENT_NAME = "praxo-core";
const CLIENT_VERSION = "0.3.0";

export interface McpClientOptions {
  command?: string;
  args?: string[];
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  transport?: McpTransport;
  protocolVersion?: string;
  clientInfo?: { name: string; version: string };
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface McpRequestOptions {
  signal?: AbortSignal;
  timeoutMs?: number;
}

export interface McpTool {
  name: string;
  description?: string;
  inputSchema?: Record<string, unknown>;
}

interface PendingRequest {
  method: string;
  resolve(value: unknown): void;
  reject(error: Error): void;
}

export class McpClient {
  private readonly options: McpClientOptions;
  private readonly transport: McpTransport;
  private readonly pending = new Map<number, PendingRequest>();
  private nextId = 1;
  private isClosed = false;
  private initialized = false;
  private negotiatedProtocolVersion = "";

  constructor(options: McpClientOptions) {
    this.options = options;
    this.transport = options.transport ?? new McpStdioTransport(options);
    this.transport.onLine((line) => this.handleLine(line));
    this.transport.onClose?.((error) => this.handleClose(error));
  }

  static async connect(options: McpClientOptions): Promise<McpClient> {
    const client = new McpClient(options);
    try {
      await client.initialize();
    } catch (error) {
      await client.close();
      throw error;
    }
    return client;
  }

  get pid(): number | undefined {
    return this.transport.pid;
  }

  get closed(): boolean {
    return this.isClosed;
  }

  get ready(): boolean {
    return this.initialized && !this.isClosed;
  }

  get protocolVersion(): string {
    return this.negotiatedProtocolVersion;
  }

  async listTools(options: McpRequestOptions = {}): Promise<McpTool[]> {
    const tools: McpTool[] = [];
    const names = new Set<string>();
    const cursors = new Set<string>();
    let cursor: string | undefined;
    for (;;) {
      const params: Record<string, unknown> = {};
      if (cursor !== undefined) {
        params.cursor = cursor;
      }
      const result = await this.request("tools/list", params, options);
      if (!isRecord(result)) {
        throw new McpProtocolError(
          "mcp: tools/list returned an invalid result"
        );
      }
      if (!Array.isArray(result.tools)) {
        throw new McpProtocolError("mcp: tools/list result is missing tools");
      }
      for (const item of result.tools) {
        if (!isRecord(item)) {
          throw new McpProtocolError(
            "mcp: tools/list contained an invalid tool"
          );
        }
        const name = typeof item.name === "string" ? item.name : "";
        if (!name) {
          throw new McpProtocolError(
            "mcp: tools/list contained a tool without a name"
          );
        }
        if (names.has(name)) {
          throw new McpProtocolError(`mcp: duplicate tool ${name}`);
        }
        names.add(name);
        const tool: McpTool = { name };
        if (typeof item.description === "string") {
          tool.description = item.description;
        }
        if (isRecord(item.inputSchema)) {
          tool.inputSchema = item.inputSchema;
        }
        tools.push(tool);
      }
      const next = result.nextCursor;
      if (next === undefined || next === null || next === "") {
        break;
      }
      const nextCursor = String(next);
      if (cursors.has(nextCursor)) {
        throw new McpProtocolError("mcp: repeated tool pagination cursor");
      }
      cursors.add(nextCursor);
      cursor = nextCursor;
    }
    return tools;
  }

  async callTool(
    name: string,
    args: Record<string, unknown> = {},
    options: McpRequestOptions = {}
  ): Promise<unknown> {
    const result = await this.request(
      "tools/call",
      { name, arguments: args },
      options
    );
    if (!isRecord(result)) {
      throw new McpProtocolError(
        `mcp: tools/call ${name} returned an invalid result`
      );
    }
    if (result.isError === true) {
      const detail = textContents(result).join("\n");
      throw new McpToolError(
        `mcp: tool ${name} failed${detail ? `: ${detail}` : ""}`
      );
    }
    if (
      result.structuredContent !== undefined &&
      result.structuredContent !== null
    ) {
      return result.structuredContent;
    }
    const texts = textContents(result);
    if (texts.length === 0) {
      return null;
    }
    if (texts.length === 1) {
      return texts[0];
    }
    return texts;
  }

  async close(): Promise<void> {
    if (this.isClosed) return;
    for (const id of [...this.pending.keys()]) {
      await this.notify("notifications/cancelled", {
        requestId: id,
        reason: "client closed",
      });
    }
    this.isClosed = true;
    this.initialized = false;
    this.failAll(new McpCancelledError("mcp: client closed"));
    await this.transport.close();
  }

  private async initialize(): Promise<void> {
    const result = await this.request("initialize", {
      protocolVersion:
        this.options.protocolVersion ?? DEFAULT_PROTOCOL_VERSION,
      capabilities: {},
      clientInfo:
        this.options.clientInfo ?? {
          name: CLIENT_NAME,
          version: CLIENT_VERSION,
        },
    });
    if (
      !isRecord(result) ||
      typeof result.protocolVersion !== "string" ||
      !result.protocolVersion
    ) {
      throw new McpProtocolError(
        "mcp: initialize did not negotiate a protocol version"
      );
    }
    this.negotiatedProtocolVersion = result.protocolVersion;
    await this.notify("notifications/initialized", {});
    this.initialized = true;
  }

  private request(
    method: string,
    params: Record<string, unknown> | undefined,
    options: McpRequestOptions = {}
  ): Promise<unknown> {
    if (this.isClosed) {
      return Promise.reject(new McpTransportError("mcp: client is closed"));
    }
    const id = this.nextId;
    this.nextId += 1;
    const timeoutMs = options.timeoutMs ?? this.options.timeoutMs;
    const signal = options.signal ?? this.options.signal;
    return new Promise<unknown>((resolve, reject) => {
      let settled = false;
      let timer: NodeJS.Timeout | undefined;
      let onAbort: (() => void) | undefined;
      const cleanup = (): void => {
        if (timer) {
          clearTimeout(timer);
          timer = undefined;
        }
        if (signal && onAbort) {
          signal.removeEventListener("abort", onAbort);
        }
      };
      const settle = (fn: () => void): void => {
        if (settled) return;
        settled = true;
        cleanup();
        this.pending.delete(id);
        fn();
      };
      const success = (value: unknown): void => {
        settle(() => resolve(value));
      };
      const failure = (error: Error): void => {
        settle(() => reject(error));
      };
      this.pending.set(id, { method, resolve: success, reject: failure });
      if (signal?.aborted) {
        failure(new McpCancelledError(`mcp: ${method} cancelled`));
        return;
      }
      onAbort = () => {
        void this.notify("notifications/cancelled", {
          requestId: id,
          reason: "cancelled",
        });
        failure(new McpCancelledError(`mcp: ${method} cancelled`));
      };
      signal?.addEventListener("abort", onAbort, { once: true });
      const effectiveTimeout =
        timeoutMs === undefined ? DEFAULT_TIMEOUT_MS : timeoutMs;
      if (effectiveTimeout > 0) {
        timer = setTimeout(() => {
          void this.notify("notifications/cancelled", {
            requestId: id,
            reason: "timeout",
          });
          failure(
            new McpTimeoutError(
              `mcp: ${method} timed out after ${effectiveTimeout}ms`
            )
          );
        }, effectiveTimeout);
      }
      void this.send({
        jsonrpc: "2.0",
        id,
        method,
        ...(params === undefined ? {} : { params }),
      }).catch((error) => {
        failure(
          error instanceof Error
            ? error
            : new McpTransportError(String(error))
        );
      });
    });
  }

  private async notify(
    method: string,
    params: Record<string, unknown>
  ): Promise<void> {
    if (this.isClosed) return;
    try {
      await this.send({ jsonrpc: "2.0", method, params });
    } catch {
      // Notifications are best-effort.
    }
  }

  private async send(message: Record<string, unknown>): Promise<void> {
    if (this.isClosed) {
      throw new McpTransportError("mcp: client is closed");
    }
    await this.transport.send(JSON.stringify(message));
  }

  private handleLine(line: string): void {
    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      this.protocolFailure(new McpProtocolError("mcp: invalid JSON-RPC line"));
      return;
    }
    if (!isRecord(parsed)) {
      this.protocolFailure(new McpProtocolError("mcp: invalid JSON-RPC line"));
      return;
    }
    const id = parsed.id;
    if (typeof id !== "number" && typeof id !== "string") return;
    const pending = this.pending.get(Number(id));
    if (!pending) return;
    if (isRecord(parsed.error)) {
      const code =
        parsed.error.code === undefined ? "unknown" : parsed.error.code;
      const message =
        parsed.error.message === undefined
          ? "JSON-RPC error"
          : String(parsed.error.message);
      pending.reject(
        new McpError(
          `mcp: ${pending.method} failed: ${message} (${String(code)})`
        )
      );
      return;
    }
    if (!("result" in parsed)) {
      pending.reject(
        new McpProtocolError(`mcp: ${pending.method} response is missing result`)
      );
      return;
    }
    pending.resolve(parsed.result);
  }

  private handleClose(error?: Error): void {
    const wasClosed = this.isClosed;
    this.isClosed = true;
    this.initialized = false;
    if (!wasClosed) {
      this.failAll(
        error ?? new McpTransportError("mcp: transport closed")
      );
    }
  }

  private protocolFailure(error: Error): void {
    this.failAll(error);
    void this.close();
  }

  private failAll(error: Error): void {
    const pending = [...this.pending.values()];
    this.pending.clear();
    for (const request of pending) {
      request.reject(error);
    }
  }
}

export class McpToolAdapter implements Tool {
  readonly name: string;
  readonly description: string;
  readonly inputSchema?: Record<string, unknown>;

  constructor(
    private readonly client: McpClient,
    private readonly info: McpTool,
    private readonly options: McpRequestOptions = {}
  ) {
    this.name = info.name;
    this.description = info.description ?? "";
    this.inputSchema = info.inputSchema;
  }

  spec(): ToolSpec {
    const spec: ToolSpec = {
      name: this.name,
      description: this.description,
    };
    if (this.inputSchema !== undefined) {
      spec.parameters = this.inputSchema;
    }
    return spec;
  }

  invoke(args: Record<string, unknown>): Promise<unknown> {
    return this.client.callTool(this.name, args, this.options);
  }
}

export function mcpTools(
  client: McpClient,
  tools: McpTool[],
  options: McpRequestOptions = {}
): McpToolAdapter[] {
  return tools.map((info) => new McpToolAdapter(client, info, options));
}

export function registerMcpTools(
  registry: Registry,
  client: McpClient,
  tools: McpTool[],
  options: McpRequestOptions = {}
): McpToolAdapter[] {
  const adapters = mcpTools(client, tools, options);
  for (const tool of adapters) {
    registry.register(tool);
  }
  return adapters;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" && value !== null && !Array.isArray(value)
  );
}

function textContents(result: Record<string, unknown>): string[] {
  if (!Array.isArray(result.content)) return [];
  const texts: string[] = [];
  for (const item of result.content) {
    if (!isRecord(item) || item.type !== "text") continue;
    if (typeof item.text === "string") {
      texts.push(item.text);
    }
  }
  return texts;
}
