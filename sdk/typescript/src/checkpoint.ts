import { CheckpointError, TypeNotAllowedError } from "./errors";

export interface Envelope {
  type: string;
  data: unknown;
}

export type Factory = () => unknown;

export class Allowlist {
  private readonly factories = new Map<string, Factory>();

  register(name: string, factory: Factory): void {
    if (!name) {
      throw new CheckpointError(
        "checkpoint: allowlist type name is required"
      );
    }
    if (!factory) {
      throw new CheckpointError("checkpoint: allowlist factory is required");
    }
    this.factories.set(name, factory);
  }

  marshal(name: string, value: unknown): string {
    if (!this.factories.has(name)) {
      throw new TypeNotAllowedError(
        `checkpoint: payload type not allowed: ${name}`
      );
    }
    return JSON.stringify({ type: name, data: value });
  }

  unmarshal(data: string | Buffer): unknown {
    const text = Buffer.isBuffer(data) ? data.toString("utf8") : data;
    const envelope = JSON.parse(text) as Envelope;
    if (!envelope || typeof envelope !== "object") {
      throw new CheckpointError("checkpoint: envelope must be an object");
    }
    const factory = this.factories.get(envelope.type);
    if (!factory) {
      throw new TypeNotAllowedError(
        `checkpoint: payload type not allowed: ${envelope.type}`
      );
    }
    const target = factory();
    if (target === null || target === undefined) {
      throw new CheckpointError(
        `checkpoint: factory for ${envelope.type} returned nil`
      );
    }
    if (typeof target === "object" && envelope.data !== null) {
      if (typeof envelope.data === "object") {
        Object.assign(target as object, envelope.data);
      }
      return target;
    }
    return envelope.data;
  }
}
