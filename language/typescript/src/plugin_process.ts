import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomBytes } from "node:crypto";
import { StringDecoder } from "node:string_decoder";

import { PluginError, PraxoError } from "./errors";

export const PLUGIN_PROTOCOL_VERSION = 1;
export const PLUGIN_CONTROL_SERVICE = "host.control";
export const PLUGIN_HEALTH_METHOD = "health";
export const PLUGIN_SHUTDOWN_METHOD = "shutdown";
export const PLUGIN_CANCEL_METHOD = "cancel";
export const PLUGIN_DEFAULT_TOKEN_ENV = "PRAXOVELA_PLUGIN_TOKEN";

export type PluginCallCode =
  | "CAPABILITY_DENIED"
  | "NOT_ACTIVE"
  | "NOT_FOUND"
  | "INVALID_REQUEST"
  | "TIMEOUT"
  | "INTERNAL"
  | "CANCELED";

const CALL_CODES = new Set<string>([
  "CAPABILITY_DENIED",
  "NOT_ACTIVE",
  "NOT_FOUND",
  "INVALID_REQUEST",
  "TIMEOUT",
  "INTERNAL",
  "CANCELED",
]);

export class PluginCallError extends PraxoError {
  readonly callCode: PluginCallCode;

  constructor(code: string, message: string = "") {
    super(message || code, "PLUGIN_CALL");
    this.callCode = CALL_CODES.has(code)
      ? (code as PluginCallCode)
      : "INTERNAL";
  }
}

export interface ProcessHostConfig {
  pluginId: string;
  path: string;
  args?: string[];
  dir?: string;
  env?: NodeJS.ProcessEnv;
  token?: string;
  tokenEnvVar?: string;
  startTimeoutMs?: number;
  invokeTimeoutMs?: number;
  gracePeriodMs?: number;
  maxFrameBytes?: number;
}

interface PendingCall {
  resolve: (payload: Buffer) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

interface WireResponse {
  id?: unknown;
  version?: unknown;
  ok?: unknown;
  code?: unknown;
  message?: unknown;
  payload?: unknown;
}

export class ProcessHost {
  readonly pluginId: string;
  private readonly config: ProcessHostConfig;
  private readonly token: string;
  private process: ChildProcessWithoutNullStreams | null = null;
  private readonly pending = new Map<string, PendingCall>();
  private readonly decoder = new StringDecoder("utf8");
  private buffer = "";
  private stderr = "";
  private sequence = 0;
  private active = false;

  constructor(config: ProcessHostConfig) {
    if (!config.pluginId) throw new PluginError("plugin: PluginID is required");
    if (!config.path) throw new PluginError("plugin: path is required");
    this.config = config;
    this.pluginId = config.pluginId;
    this.token = config.token || randomBytes(32).toString("hex");
  }

  get isActive(): boolean {
    return this.active;
  }

  async start(): Promise<void> {
    if (this.process) throw new PluginError("plugin: host already started");
    const env: NodeJS.ProcessEnv = {
      ...(this.config.env ?? process.env),
      [this.config.tokenEnvVar ?? PLUGIN_DEFAULT_TOKEN_ENV]: this.token,
    };
    const child = spawn(this.config.path, this.config.args ?? [], {
      cwd: this.config.dir,
      env,
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.process = child;
    child.stdout.on("data", (chunk: Buffer) => this.onStdout(chunk));
    child.stderr.on("data", (chunk: Buffer) => {
      if (this.stderr.length < 16 << 10) {
        this.stderr += chunk.toString("utf8").slice(0, (16 << 10) - this.stderr.length);
      }
    });
    child.on("exit", () => this.onExit());
    child.on("error", () => this.onExit());
    try {
      await this.call(
        PLUGIN_CONTROL_SERVICE,
        PLUGIN_HEALTH_METHOD,
        Buffer.alloc(0),
        this.config.startTimeoutMs ?? 10_000,
      );
    } catch (error) {
      this.terminate();
      throw error;
    }
    this.active = true;
  }

  async invoke(
    service: string,
    method: string,
    payload: Buffer = Buffer.alloc(0),
    timeoutMs?: number,
  ): Promise<Buffer> {
    if (!this.active) {
      throw new PluginCallError("NOT_ACTIVE", "plugin: host is not active");
    }
    return this.call(
      service,
      method,
      payload,
      timeoutMs ?? this.config.invokeTimeoutMs ?? 30_000,
    );
  }

  async stop(): Promise<void> {
    if (!this.process) return;
    try {
      if (this.active) {
        await this.call(
          PLUGIN_CONTROL_SERVICE,
          PLUGIN_SHUTDOWN_METHOD,
          Buffer.alloc(0),
          this.config.gracePeriodMs ?? 5_000,
        );
      }
    } catch {
      // best effort
    }
    this.active = false;
    const child = this.process;
    await new Promise<void>((resolve) => {
      const timer = setTimeout(() => {
        child.kill("SIGTERM");
        setTimeout(() => child.kill("SIGKILL"), this.config.gracePeriodMs ?? 5_000);
        resolve();
      }, this.config.gracePeriodMs ?? 5_000);
      child.once("exit", () => {
        clearTimeout(timer);
        resolve();
      });
      if (child.exitCode !== null) {
        clearTimeout(timer);
        resolve();
      }
    });
    this.process = null;
  }

  stderrText(): string {
    return this.stderr;
  }

  private call(
    service: string,
    method: string,
    payload: Buffer,
    timeoutMs: number,
  ): Promise<Buffer> {
    const child = this.process;
    if (!child || !child.stdin.writable) {
      return Promise.reject(new PluginCallError("INTERNAL", "plugin: process is closed"));
    }
    this.sequence += 1;
    const id = `req-${this.sequence}`;
    const frame = {
      id,
      version: PLUGIN_PROTOCOL_VERSION,
      plugin_id: this.config.pluginId,
      service,
      method,
      token: this.token,
      payload: payload.toString("base64"),
    };
    const encoded = `${JSON.stringify(frame)}\n`;
    if (Buffer.byteLength(encoded) > (this.config.maxFrameBytes ?? 8 << 20)) {
      return Promise.reject(
        new PluginCallError("INVALID_REQUEST", "plugin: request frame too large"),
      );
    }
    return new Promise<Buffer>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        this.sendCancel(id);
        reject(new PluginCallError("TIMEOUT", "plugin: invocation timed out"));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      child.stdin.write(encoded, (error) => {
        if (error) {
          clearTimeout(timer);
          this.pending.delete(id);
          reject(new PluginCallError("INTERNAL", error.message));
        }
      });
    });
  }

  private sendCancel(id: string): void {
    const child = this.process;
    if (!child || !child.stdin.writable) return;
    const frame = {
      id,
      version: PLUGIN_PROTOCOL_VERSION,
      plugin_id: this.config.pluginId,
      service: PLUGIN_CONTROL_SERVICE,
      method: PLUGIN_CANCEL_METHOD,
      token: this.token,
    };
    child.stdin.write(`${JSON.stringify(frame)}\n`);
  }

  private onStdout(chunk: Buffer): void {
    this.buffer += this.decoder.write(chunk);
    for (;;) {
      const index = this.buffer.indexOf("\n");
      if (index < 0) break;
      const line = this.buffer.slice(0, index).trim();
      this.buffer = this.buffer.slice(index + 1);
      if (line) this.onLine(line);
    }
  }

  private onLine(line: string): void {
    let response: WireResponse;
    try {
      response = JSON.parse(line) as WireResponse;
    } catch {
      return;
    }
    const id = typeof response.id === "string" ? response.id : "";
    const pending = this.pending.get(id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pending.delete(id);
    if (response.ok !== true) {
      pending.reject(
        new PluginCallError(
          typeof response.code === "string" ? response.code : "INTERNAL",
          typeof response.message === "string" ? response.message : "",
        ),
      );
      return;
    }
    if (typeof response.payload !== "string") {
      pending.reject(new PluginCallError("INTERNAL", "plugin: invalid payload"));
      return;
    }
    pending.resolve(Buffer.from(response.payload, "base64"));
  }

  private onExit(): void {
    this.active = false;
    for (const [id, pending] of this.pending) {
      clearTimeout(pending.timer);
      this.pending.delete(id);
      pending.reject(
        new PluginCallError(
          "INTERNAL",
          this.stderrText().slice(0, 512) || "plugin: process exited",
        ),
      );
    }
  }

  private terminate(): void {
    this.active = false;
    const child = this.process;
    if (!child) return;
    try {
      child.kill("SIGTERM");
    } catch {
      // ignore
    }
    this.process = null;
  }
}
