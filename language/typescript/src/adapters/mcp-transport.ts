import { ChildProcessWithoutNullStreams, spawn } from "node:child_process";

import { McpTransportError } from "../errors";
import type { McpClientOptions } from "./mcp";

export interface McpTransport {
  readonly pid?: number;
  send(line: string): void | Promise<void>;
  onLine(handler: (line: string) => void): void;
  onClose?(handler: (error?: Error) => void): void;
  close(): void | Promise<void>;
}

export class McpStdioTransport implements McpTransport {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly lineHandlers: ((line: string) => void)[] = [];
  private readonly closeHandlers: ((error?: Error) => void)[] = [];
  private readonly exitedPromise: Promise<void>;
  private resolveExited: () => void = () => {};
  private buffer = "";
  private closing = false;
  private exited = false;
  private closeNotified = false;

  constructor(options: McpClientOptions) {
    if (!options.command) {
      throw new McpTransportError("mcp: command is required");
    }
    this.child = spawn(options.command, options.args ?? [], {
      cwd: options.cwd,
      env: options.env,
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.exitedPromise = new Promise<void>((resolve) => {
      this.resolveExited = resolve;
    });
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk) => this.consume(String(chunk)));
    this.child.stderr.resume();
    this.child.once("close", () => {
      this.exited = true;
      this.resolveExited();
      this.notifyClose();
    });
    this.child.once("error", (error: Error) => {
      this.exited = true;
      this.resolveExited();
      this.notifyClose(
        new McpTransportError(`mcp: child process error: ${error.message}`)
      );
    });
  }

  get pid(): number | undefined {
    return this.child.pid;
  }

  send(line: string): void {
    if (this.closing) {
      throw new McpTransportError("mcp: transport is closed");
    }
    this.child.stdin.write(`${line}\n`);
  }

  onLine(handler: (line: string) => void): void {
    this.lineHandlers.push(handler);
  }

  onClose(handler: (error?: Error) => void): void {
    this.closeHandlers.push(handler);
  }

  async close(): Promise<void> {
    if (this.closing) {
      await this.exitedPromise;
      return;
    }
    this.closing = true;
    try {
      this.child.stdin.end();
    } catch {
      // The child may already be gone.
    }
    await Promise.race([this.exitedPromise, wait(200)]);
    if (!this.exited) {
      try {
        this.child.kill("SIGTERM");
      } catch {
        // Ignore kill failures on an already-exited child.
      }
      await Promise.race([this.exitedPromise, wait(500)]);
    }
    if (!this.exited) {
      try {
        this.child.kill("SIGKILL");
      } catch {
        // Ignore kill failures on an already-exited child.
      }
      await Promise.race([this.exitedPromise, wait(200)]);
    }
    this.notifyClose();
  }

  private consume(chunk: string): void {
    this.buffer += chunk;
    let index = this.buffer.indexOf("\n");
    while (index >= 0) {
      const line = this.buffer.slice(0, index).replace(/\r$/, "");
      this.buffer = this.buffer.slice(index + 1);
      if (line.trim()) {
        for (const handler of this.lineHandlers) {
          handler(line);
        }
      }
      index = this.buffer.indexOf("\n");
    }
  }

  private notifyClose(error?: Error): void {
    if (this.closeNotified) return;
    this.closeNotified = true;
    for (const handler of this.closeHandlers) {
      handler(error);
    }
  }
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    timer.unref?.();
  });
}
