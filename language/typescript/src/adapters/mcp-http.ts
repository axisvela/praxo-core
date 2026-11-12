import { McpProtocolError, McpTransportError } from "../errors";
import type { McpTransport } from "./mcp-transport";

const DEFAULT_PROTOCOL_VERSION = "2025-03-26";
const DEFAULT_ACCEPT = "application/json, text/event-stream";

export interface McpStreamableHTTPOptions {
  endpoint: string;
  headers?: Record<string, string>;
  protocolVersion?: string;
  fetch?: typeof fetch;
}

export class McpStreamableHTTPTransport implements McpTransport {
  private readonly endpoint: string;
  private readonly headers: Record<string, string>;
  private readonly fetchImpl: typeof fetch;
  private readonly lineHandlers: ((line: string) => void)[] = [];
  private readonly closeHandlers: ((error?: Error) => void)[] = [];
  private protocolVersion: string;
  private sessionId = "";
  private closed = false;
  private closeNotified = false;

  constructor(options: McpStreamableHTTPOptions) {
    this.endpoint = validateEndpoint(options.endpoint);
    this.headers = options.headers ?? {};
    this.protocolVersion = options.protocolVersion ?? DEFAULT_PROTOCOL_VERSION;
    this.fetchImpl = options.fetch ?? fetch;
  }

  async send(line: string): Promise<void> {
    if (this.closed) {
      throw new McpTransportError("mcp: transport is closed");
    }
    let message: unknown;
    try {
      message = JSON.parse(line);
    } catch {
      throw new McpProtocolError("mcp: invalid JSON-RPC message");
    }
    if (!isRecord(message)) {
      throw new McpProtocolError("mcp: invalid JSON-RPC message");
    }
    await this.post(line);
  }

  onLine(handler: (line: string) => void): void {
    this.lineHandlers.push(handler);
  }

  onClose(handler: (error?: Error) => void): void {
    this.closeHandlers.push(handler);
  }

  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    if (this.sessionId) {
      try {
        await this.fetchImpl(this.endpoint, {
          method: "DELETE",
          headers: this.requestHeaders(),
        });
      } catch {
        // Session termination is best-effort.
      }
    }
    this.notifyClose();
  }

  private async post(line: string): Promise<void> {
    let response: Response;
    try {
      response = await this.fetchImpl(this.endpoint, {
        method: "POST",
        headers: this.requestHeaders(),
        body: line,
      });
    } catch (error) {
      throw new McpTransportError(
        `mcp: HTTP transport failed: ${
          error instanceof Error ? error.message : String(error)
        }`
      );
    }
    const session = response.headers.get("mcp-session-id");
    if (session) this.sessionId = session;
    if (response.status === 202 || response.status === 204) {
      return;
    }
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 512);
      throw new McpTransportError(
        `mcp: HTTP ${response.status}${detail ? `: ${detail}` : ""}`
      );
    }
    const contentType = response.headers.get("content-type") ?? "";
    if (contentType.includes("text/event-stream")) {
      await this.readSSE(response);
      return;
    }
    const text = await response.text();
    if (!text.trim()) return;
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      throw new McpProtocolError("mcp: server sent invalid JSON");
    }
    for (const item of Array.isArray(parsed) ? parsed : [parsed]) {
      this.handleMessage(item);
    }
  }

  private async readSSE(response: Response): Promise<void> {
    if (!response.body) {
      throw new McpTransportError("mcp: SSE response has no body");
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      buffer = buffer.replace(/\r\n/g, "\n");
      let index = buffer.indexOf("\n\n");
      while (index >= 0) {
        const event = buffer.slice(0, index);
        buffer = buffer.slice(index + 2);
        this.handleEvent(event);
        index = buffer.indexOf("\n\n");
      }
    }
    if (buffer.trim()) {
      this.handleEvent(buffer);
    }
  }

  private handleEvent(event: string): void {
    const data: string[] = [];
    for (const line of event.split("\n")) {
      if (line.startsWith(":")) continue;
      if (line.startsWith("data:")) {
        data.push(line.slice(5).replace(/^ /, ""));
      }
    }
    if (data.length === 0) return;
    let parsed: unknown;
    try {
      parsed = JSON.parse(data.join("\n"));
    } catch {
      throw new McpProtocolError("mcp: server sent invalid SSE JSON");
    }
    this.handleMessage(parsed);
  }

  private handleMessage(message: unknown): void {
    if (!isRecord(message)) {
      throw new McpProtocolError(
        "mcp: server sent a non-object JSON-RPC message"
      );
    }
    const result = message.result;
    if (isRecord(result) && typeof result.protocolVersion === "string") {
      this.protocolVersion = result.protocolVersion;
    }
    const line = JSON.stringify(message);
    for (const handler of this.lineHandlers) {
      handler(line);
    }
  }

  private requestHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      "content-type": "application/json",
      accept: DEFAULT_ACCEPT,
      "mcp-protocol-version": this.protocolVersion,
      ...this.headers,
    };
    if (this.sessionId) {
      headers["mcp-session-id"] = this.sessionId;
    }
    return headers;
  }

  private notifyClose(error?: Error): void {
    if (this.closeNotified) return;
    this.closeNotified = true;
    for (const handler of this.closeHandlers) {
      handler(error);
    }
  }
}

function validateEndpoint(endpoint: string): string {
  let parsed: URL;
  try {
    parsed = new URL(endpoint);
  } catch {
    throw new McpTransportError("mcp: invalid HTTP endpoint");
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new McpTransportError("mcp: invalid HTTP endpoint");
  }
  if (parsed.protocol === "http:" && !isLoopback(parsed.hostname)) {
    throw new McpTransportError("mcp: HTTP endpoint must use HTTPS");
  }
  return endpoint;
}

function isLoopback(hostname: string): boolean {
  const host = hostname.replace(/^\[|\]$/g, "").toLowerCase();
  return (
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "::1" ||
    host.startsWith("127.")
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" && value !== null && !Array.isArray(value)
  );
}
