import { randomUUID } from "node:crypto";

export type Frame = string;

export const FRAME_EVENT = "event";
export const FRAME_DECISION = "decision";
export const FRAME_EXPERIENCE = "experience";
export const FRAME_PROCEDURE = "procedure";
export const FRAME_WORKSPACE_STATE = "workspace_state";
export const FRAME_CONSTRAINT = "constraint";
export const FRAME_INTENTION = "intention";

export interface MemoryRecord {
  id: string;
  frame: Frame;
  content: string;
  metadata?: Record<string, unknown>;
  createdAt?: string;
}

export interface Store {
  put(sessionId: string, record: MemoryRecord): Promise<void>;
  search(
    sessionId: string,
    query: string,
    limit?: number
  ): Promise<MemoryRecord[]>;
}

interface Stored {
  record: MemoryRecord;
  search: string;
}

export class MemoryStore implements Store {
  private readonly records = new Map<string, Stored[]>();

  async put(sessionId: string, record: MemoryRecord): Promise<void> {
    const stored: MemoryRecord = {
      ...record,
      id: record.id || `mem-${randomUUID()}`,
      createdAt: record.createdAt ?? new Date().toISOString(),
    };
    const list = this.records.get(sessionId) ?? [];
    list.push({ record: stored, search: stored.content.toLowerCase() });
    this.records.set(sessionId, list);
  }

  async search(
    sessionId: string,
    query: string,
    limit = 0
  ): Promise<MemoryRecord[]> {
    const needle = query.trim().toLowerCase();
    const matches = (this.records.get(sessionId) ?? [])
      .filter((item) => !needle || item.search.includes(needle))
      .map((item) => item.record)
      .sort(
        (a, b) =>
          Date.parse(b.createdAt ?? "1970-01-01T00:00:00Z") -
          Date.parse(a.createdAt ?? "1970-01-01T00:00:00Z")
      );
    return limit > 0 ? matches.slice(0, limit) : matches;
  }
}

export class ContextAssembler {
  constructor(
    private readonly store: Store,
    private readonly limit = 8
  ) {}

  assemble(sessionId: string, query: string): Promise<MemoryRecord[]> {
    return this.store.search(
      sessionId,
      query,
      this.limit > 0 ? this.limit : 8
    );
  }
}
