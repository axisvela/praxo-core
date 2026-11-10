import { Event, Sink } from "../event";

export interface HarmovelaHttpRequest {
  method: "POST";
  url: string;
  headers: Record<string, string>;
  body: string;
}

export interface HarmovelaHttpResponse {
  status: number;
  body: string;
}

export type HarmovelaTransport = (
  request: HarmovelaHttpRequest
) => Promise<HarmovelaHttpResponse> | HarmovelaHttpResponse;

export interface HarmovelaSinkOptions {
  baseUrl: string;
  source?: string;
  specVersion?: string;
  timeoutMs?: number;
  transport?: HarmovelaTransport;
}

export class HarmovelaSink implements Sink {
  private readonly baseUrl: string;
  private readonly source: string;
  private readonly specVersion: string;
  private readonly timeoutMs: number;
  private readonly transport: HarmovelaTransport;

  constructor(options: HarmovelaSinkOptions) {
    this.baseUrl = options.baseUrl.replace(/\/+$/, "");
    this.source = options.source || "praxo-core";
    this.specVersion = options.specVersion || "0.2";
    this.timeoutMs = options.timeoutMs ?? 30000;
    this.transport = options.transport ?? this.post;
  }

  async emit(event: Event): Promise<void> {
    const body = JSON.stringify(this.envelope(event));
    const response = await this.transport({
      method: "POST",
      url: `${this.baseUrl}/events`,
      headers: { "content-type": "application/json" },
      body,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new Error(
        `harmovela: HTTP ${response.status}: ${response.body.slice(0, 512).trim()}`
      );
    }
  }

  private envelope(event: Event): Record<string, unknown> {
    const at = event.at ? new Date(event.at) : new Date();
    const payload: Record<string, unknown> = { ...(event.data ?? {}) };
    if (event.sessionId) payload.session_id = event.sessionId;
    if (event.runId) payload.run_id = event.runId;
    return {
      spec_version: this.specVersion,
      id: eventId(event, at),
      type: event.type,
      source: this.source,
      created_at: rfc3339Nanos(at),
      payload,
    };
  }

  private async post(
    request: HarmovelaHttpRequest
  ): Promise<HarmovelaHttpResponse> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await fetch(request.url, {
        method: request.method,
        headers: request.headers,
        body: request.body,
        signal: controller.signal,
      });
      return { status: response.status, body: await response.text() };
    } finally {
      clearTimeout(timer);
    }
  }
}

function eventId(event: Event, at: Date): string {
  const prefix = event.runId || event.sessionId || "event";
  const nanos = BigInt(at.getTime()) * 1_000_000n;
  return `${prefix}-${nanos.toString()}`;
}

function rfc3339Nanos(at: Date): string {
  return `${at.toISOString().slice(0, 23)}000000Z`;
}
