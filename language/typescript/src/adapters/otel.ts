import { Event, Sink } from "../event";

export interface OtelHttpRequest {
  method: "POST";
  url: string;
  headers: Record<string, string>;
  body: string;
}

export interface OtelHttpResponse {
  status: number;
  body: string;
}

export type OtelTransport = (
  request: OtelHttpRequest
) => Promise<OtelHttpResponse> | OtelHttpResponse;

export interface OtelSinkOptions {
  endpoint?: string;
  serviceName?: string;
  transport?: OtelTransport;
  allowedDataKeys?: string[];
  timeoutMs?: number;
}

export class OtelSink implements Sink {
  private readonly endpoint: string;
  private readonly serviceName: string;
  private readonly transport: OtelTransport;
  private readonly allowedDataKeys: string[];
  private readonly timeoutMs: number;

  constructor(options: OtelSinkOptions = {}) {
    this.endpoint = options.endpoint || "http://127.0.0.1:4318/v1/traces";
    this.serviceName = options.serviceName || "praxo-core";
    this.transport = options.transport ?? this.post;
    this.allowedDataKeys = options.allowedDataKeys ?? [];
    this.timeoutMs = options.timeoutMs ?? 30000;
  }

  async emit(event: Event): Promise<void> {
    const response = await this.transport({
      method: "POST",
      url: this.endpoint,
      headers: { "content-type": "application/json" },
      body: JSON.stringify(this.payload(event)),
    });
    if (response.status < 200 || response.status >= 300) {
      throw new Error(
        `otel: HTTP ${response.status}: ${response.body.slice(0, 512).trim()}`
      );
    }
  }

  private payload(event: Event): Record<string, unknown> {
    const at = event.at ? new Date(event.at) : new Date();
    const nanos = String(BigInt(at.getTime()) * 1000000n);
    const key = [
      event.sessionId,
      event.runId ?? "",
      event.type,
      at.toISOString(),
      stableJson(event.data ?? {}),
    ].join("|");
    const traceId =
      hex(fnv1a(key, 0xcbf29ce484222325n), 16) +
      hex(fnv1a(key, 0x84222325cbf29ce4n), 16);
    const spanId = hex(fnv1a(key + "|span", 0x100000001b3n), 16);
    const attributes: Array<Record<string, unknown>> = [
      attribute("praxo.event.type", event.type),
    ];
    if (event.sessionId) {
      attributes.push(attribute("praxo.session.id", event.sessionId));
    }
    if (event.runId) {
      attributes.push(attribute("praxo.run.id", event.runId));
    }
    attributes.push(attribute("praxo.event.at", at.toISOString()));
    for (const name of this.allowedDataKeys) {
      if (Object.prototype.hasOwnProperty.call(event.data ?? {}, name)) {
        attributes.push(
          attribute("praxo.event.data." + name, text((event.data ?? {})[name]))
        );
      }
    }
    return {
      resourceSpans: [
        {
          resource: {
            attributes: [attribute("service.name", this.serviceName)],
          },
          scopeSpans: [
            {
              scope: { name: "praxo-core" },
              spans: [
                {
                  traceId,
                  spanId,
                  name: "praxo." + event.type,
                  kind: 1,
                  startTimeUnixNano: nanos,
                  endTimeUnixNano: nanos,
                  attributes,
                },
              ],
            },
          ],
        },
      ],
    };
  }

  private async post(request: OtelHttpRequest): Promise<OtelHttpResponse> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await fetch(request.url, {
        method: request.method,
        headers: request.headers,
        body: request.body,
        signal: controller.signal,
      });
      return { status: response.status, body: (await response.text()).slice(0, 512) };
    } finally {
      clearTimeout(timer);
    }
  }
}

function attribute(key: string, value: string): Record<string, unknown> {
  return { key, value: { stringValue: value } };
}

function text(value: unknown): string {
  return typeof value === "string" ? value : stableJson(value);
}

function stableJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableJson).join(",")}]`;
  }
  const object = value as Record<string, unknown>;
  const entries = Object.keys(object)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableJson(object[key])}`);
  return `{${entries.join(",")}}`;
}

function fnv1a(textValue: string, seed: bigint): bigint {
  let value = seed & 0xffffffffffffffffn;
  for (const byte of Buffer.from(textValue, "utf8")) {
    value ^= BigInt(byte);
    value = (value * 0x100000001b3n) & 0xffffffffffffffffn;
  }
  return value;
}

function hex(value: bigint, width: number): string {
  return value.toString(16).padStart(width, "0").slice(-width);
}
