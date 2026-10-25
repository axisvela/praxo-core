import * as fs from "node:fs";

import { ContextBudgetError } from "./errors";
import {
  Message,
  Model,
  Request,
  ROLE_SYSTEM,
  ROLE_TOOL,
} from "./model";

export const MAX_AGENTS_MD_BYTES = 64 << 10;
export const COMPACT_MARKER_PREFIX = "[context compacted:";
export const SUMMARY_MARKER_PREFIX = "[context summary:";
export const DEFAULT_SUMMARY_PROMPT =
  "Summarize the conversation so far. Preserve decisions, open tasks, " +
  "tool results, constraints, and user preferences. Be concise.";

function byteLength(value: string | undefined): number {
  return Buffer.byteLength(value ?? "", "utf8");
}

export function estimateTokens(messages: Message[]): number {
  let total = 0;
  for (const message of messages) {
    total +=
      4 +
      Math.floor(byteLength(message.content) / 4) +
      Math.floor(byteLength(message.toolId) / 4);
    for (const block of message.contentBlocks ?? []) {
      total +=
        4 +
        Math.floor(byteLength(block.text) / 4) +
        Math.floor(byteLength(block.imageUrl) / 4) +
        Math.floor(byteLength(block.data) / 4);
    }
    for (const call of message.toolCalls ?? []) {
      total += 4 + Math.floor(byteLength(call.name) / 4);
      total += Math.floor(
        byteLength(stableStringify(call.arguments)) / 4
      );
    }
  }
  return total;
}

export function truncateToTokens(value: string, tokens: number): string {
  if (tokens <= 0) return "";
  const limit = tokens * 4;
  const raw = Buffer.from(value, "utf8");
  if (raw.length <= limit) return value;
  if (limit <= 16) return raw.subarray(0, limit).toString("utf8");
  return (
    raw.subarray(0, limit - 16).toString("utf8") + "\n[truncated]"
  );
}

export interface ContextCompactor {
  compact(messages: Message[], budget: ContextBudget): Promise<Message[]>;
}

export class ContextBudget {
  constructor(
    readonly maxTokens = 0,
    readonly keepRecent = 0
  ) {}

  compact(messages: Message[]): [Message[], boolean] {
    if (this.maxTokens <= 0) return [messages, true];
    if (estimateTokens(messages) <= this.maxTokens) {
      return [messages, true];
    }

    const system: Message[] = [];
    const rest: Message[] = [];
    for (const message of messages) {
      if (message.role === ROLE_SYSTEM) {
        if (message.content?.startsWith(COMPACT_MARKER_PREFIX)) continue;
        system.push(structuredClone(message));
        continue;
      }
      rest.push(structuredClone(message));
    }

    if (estimateTokens(system) > this.maxTokens) {
      if (!system.length) return [[], false];
      const first = system[0];
      first.content = truncateToTokens(
        first.content ?? "",
        this.maxTokens - 4
      );
      if (estimateTokens([first]) > this.maxTokens) return [[], false];
      system.splice(0, system.length, first);
    }

    const keep = this.keepRecent > 0 ? this.keepRecent : 4;
    let start = Math.max(0, rest.length - keep);
    while (start > 0 && rest[start].role === ROLE_TOOL) start -= 1;

    const marker: Message = {
      role: ROLE_SYSTEM,
      content: `${COMPACT_MARKER_PREFIX} ${start} older messages omitted]`,
    };
    let kept = rest.slice(start);
    let out = buildCompacted(system, marker, start > 0, kept);
    while (estimateTokens(out) > this.maxTokens && kept.length > 1) {
      if (kept[1].role === ROLE_TOOL) break;
      kept = kept.slice(1);
      out = buildCompacted(system, marker, start > 0, kept);
    }
    if (estimateTokens(out) > this.maxTokens) return [[], false];
    return [out, true];
  }
}

function buildCompacted(
  system: Message[],
  marker: Message,
  includeMarker: boolean,
  kept: Message[]
): Message[] {
  return [...system, ...(includeMarker ? [marker] : []), ...kept];
}

export class ModelSummarizer implements ContextCompactor {
  constructor(
    private readonly model: Model | null,
    private readonly prompt = "",
    private readonly maxSummaryTokens = 0
  ) {}

  async compact(
    messages: Message[],
    budget: ContextBudget
  ): Promise<Message[]> {
    if (
      budget.maxTokens <= 0 ||
      estimateTokens(messages) <= budget.maxTokens
    ) {
      return messages;
    }
    if (!this.model) return fitBudget(messages, budget);

    const system: Message[] = [];
    const rest: Message[] = [];
    for (const message of messages) {
      if (message.role === ROLE_SYSTEM) {
        if (
          message.content?.startsWith(COMPACT_MARKER_PREFIX) ||
          message.content?.startsWith(SUMMARY_MARKER_PREFIX)
        ) {
          continue;
        }
        system.push(structuredClone(message));
        continue;
      }
      rest.push(structuredClone(message));
    }

    const keep = budget.keepRecent > 0 ? budget.keepRecent : 4;
    let start = Math.max(0, rest.length - keep);
    while (start > 0 && rest[start].role === ROLE_TOOL) start -= 1;
    if (start === 0) return fitBudget(messages, budget);

    const summary = await this.summarize(rest.slice(0, start));
    if (!summary.trim()) return fitBudget(messages, budget);
    const maxSummary =
      this.maxSummaryTokens > 0
        ? this.maxSummaryTokens
        : Math.floor(budget.maxTokens / 4);
    const trimmed = truncateToTokens(summary.trim(), maxSummary);
    const out: Message[] = [
      ...system,
      {
        role: ROLE_SYSTEM,
        content: `${SUMMARY_MARKER_PREFIX} ${trimmed}]`,
      },
      ...rest.slice(start),
    ];
    return fitBudget(out, budget);
  }

  private async summarize(messages: Message[]): Promise<string> {
    const prompt = this.prompt.trim() || DEFAULT_SUMMARY_PROMPT;
    const request: Request = {
      messages: [{ role: ROLE_SYSTEM, content: prompt }, ...messages],
    };
    try {
      const response = await (this.model as Model).generate(request);
      return response.message.content ?? "";
    } catch {
      return "";
    }
  }
}

function fitBudget(
  messages: Message[],
  budget: ContextBudget
): Message[] {
  const [out, ok] = budget.compact(messages);
  if (!ok) throw new ContextBudgetError("agent: context budget exceeded");
  return out;
}

export interface Offloader {
  offload(
    toolName: string,
    toolCallId: string,
    data: Buffer
  ): Promise<string>;
}

export class OffloadFunc implements Offloader {
  constructor(
    private readonly fn: (
      toolName: string,
      toolCallId: string,
      data: Buffer
    ) => Promise<string> | string
  ) {}

  async offload(
    toolName: string,
    toolCallId: string,
    data: Buffer
  ): Promise<string> {
    return this.fn(toolName, toolCallId, data);
  }
}

export function loadAgentsMd(paths: string[]): string {
  const chunks: string[] = [];
  let used = 0;
  for (const rawPath of paths) {
    if (!rawPath.trim()) continue;
    const text = fs.readFileSync(rawPath, "utf8").trim();
    if (!text) continue;
    const header = `## AGENTS.md: ${rawPath}\n`;
    const chunk = header + text;
    const size = byteLength(chunk);
    if (used + size > MAX_AGENTS_MD_BYTES) {
      const remaining = MAX_AGENTS_MD_BYTES - used;
      if (remaining <= byteLength(header)) break;
      const truncated = Buffer.from(chunk, "utf8")
        .subarray(0, remaining)
        .toString("utf8");
      chunks.push(truncated + "\n[truncated]");
      break;
    }
    chunks.push(chunk);
    used += size;
  }
  return chunks.join("\n\n");
}

function stableStringify(value: unknown): string {
  return JSON.stringify(sortValue(value));
}

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortValue);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      out[key] = sortValue((value as Record<string, unknown>)[key]);
    }
    return out;
  }
  return value;
}
