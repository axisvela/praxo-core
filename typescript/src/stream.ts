export const STREAM_VALUES = "values";
export const STREAM_UPDATES = "updates";
export const STREAM_MESSAGES = "messages";
export const STREAM_TASKS = "tasks";
export const STREAM_DEBUG = "debug";
export const STREAM_CHECKPOINT = "checkpoint";

export const STREAM_KINDS = [
  STREAM_VALUES,
  STREAM_UPDATES,
  STREAM_MESSAGES,
  STREAM_TASKS,
  STREAM_DEBUG,
  STREAM_CHECKPOINT,
] as const;

export type StreamKind = (typeof STREAM_KINDS)[number];

export interface StreamPart {
  runId: string;
  sessionId: string;
  kind: StreamKind;
  step?: number;
  data?: unknown;
  at?: string;
}
