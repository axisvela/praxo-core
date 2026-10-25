export interface Event {
  type: string;
  sessionId: string;
  runId?: string;
  data?: Record<string, unknown>;
  at?: string;
}

export interface Sink {
  emit(event: Event): Promise<void>;
}

export class MultiSink implements Sink {
  constructor(private readonly sinks: Sink[]) {}

  async emit(event: Event): Promise<void> {
    for (const sink of this.sinks) {
      if (sink) await sink.emit(event);
    }
  }
}

export type EventPredicate = (event: Event) => boolean;

export class FilterSink implements Sink {
  constructor(
    private readonly sink: Sink,
    private readonly predicate?: EventPredicate
  ) {}

  async emit(event: Event): Promise<void> {
    if (!this.sink) return;
    if (this.predicate && !this.predicate(event)) return;
    await this.sink.emit(event);
  }
}

export function eventToWire(event: Event): Record<string, unknown> {
  const out: Record<string, unknown> = {
    type: event.type,
    sessionId: event.sessionId,
    at: event.at ?? new Date().toISOString(),
  };
  if (event.runId) out.runId = event.runId;
  if (event.data && Object.keys(event.data).length) out.data = event.data;
  return out;
}
