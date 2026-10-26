import { randomUUID } from "node:crypto";

export interface ParsedToolCall {
  callId: string;
  name: string;
  operation: string;
  resource: string;
  risk: string;
  reason: string;
  idempotencyKey: string;
  input: Record<string, unknown>;
}

const DSML_INVOKE = /<｜｜DSML｜｜invoke\s+name="([^"]+)"\s*>/;
const DSML_PARAM =
  /<｜｜DSML｜｜parameter\s+name="([^"]+)"(?:\s+string="([^"]+)")?\s*>([\s\S]*?)<\/｜｜DSML｜｜parameter>/g;
const DSML_SINGULAR =
  /<｜｜DSML｜｜tool_call\s+name="([^"]+)"\s*>\s*([\s\S]*?)\s*<\/｜｜DSML｜｜tool_call>/;
const XML_TOOL =
  /<tool_call\s+name="([^"]+)"\s*>\s*([\s\S]*?)\s*<\/tool_call>/g;
const INVOKE_NAME = /<tool_name>\s*([^<]+?)\s*<\/tool_name>/;
const INVOKE_ATTR =
  /<parameters\s+actual="([\s\S]*?)">\s*<\/parameters>/;
const INVOKE_BODY = /<parameters>\s*(\{[\s\S]*?)\s*<\/parameters>/;
const TAG_TOOL =
  /<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{[\s\S]*?)\s*(?:<\/[a-zA-Z][\w.-]*>|$)/g;
const PLAIN_TOOL =
  /^\s*([a-zA-Z][\w.-]*)\s+(\{[^\n]*\})\s*$/gm;
const TODO = /<todo_(\w+?)>([\s\S]*?)<\/todo_\w+>/;
const SKILL = /<skill\.install\s+([^>]*)>([\s\S]*?)<\/skill\.install>/;
const EXCESS_NEWLINES = /\n{3,}/g;

const STRIP = [
  /<｜｜DSML｜｜tool_calls>[\s\S]*?(?:<\/｜｜DSML｜｜tool_calls>|$)/g,
  /<｜｜DSML｜｜tool_call\s+name="[^"]+"\s*>[\s\S]*?(?:<\/｜｜DSML｜｜tool_call>|$)/g,
  /<tool_call\s+name="[^"]+"\s*>[\s\S]*?(?:<\/tool_call>|$)/g,
  /<tool_call_invoke>[\s\S]*?(?:<\/tool_call_invoke>|$)/g,
  /<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{[\s\S]*?(?:<\/[a-zA-Z][\w.-]*>|$)/g,
];

export function parseToolCall(content: string): ParsedToolCall | null {
  const json = parseJsonCall(content);
  if (json) return withId(json);
  for (const parser of [
    parseDsml,
    parseXml,
    parseInvoke,
    parseTag,
    parseTodo,
    parseSkillInstall,
    parsePlain,
  ]) {
    const call = parser(content);
    if (call) return withId(call);
  }
  return null;
}

export function stripToolCallMarkup(content: string): string {
  let out = content;
  for (const pattern of STRIP) out = out.replace(pattern, "");
  return out.replace(EXCESS_NEWLINES, "\n\n").trim();
}

export function parseInputJson(raw: string): Record<string, unknown> | null {
  const parsed = tryObject(raw.trim());
  if (parsed) return parsed;
  return tryObject(raw.replace(/\\/g, "\\\\").trim());
}

function tryObject(raw: string): Record<string, unknown> | null {
  try {
    const value = JSON.parse(raw);
    return isObject(value) ? value : null;
  } catch {
    return null;
  }
}

function parseJsonCall(content: string): ParsedToolCall | null {
  let value: unknown;
  try {
    value = JSON.parse(content);
  } catch {
    return null;
  }
  if (!isObject(value) || !value.name) return null;
  return {
    callId: "",
    name: String(value.name),
    operation: String(value.operation ?? ""),
    resource: String(value.resource ?? ""),
    risk: String(value.risk ?? ""),
    reason: String(value.reason ?? ""),
    idempotencyKey: String(value.idempotency_key ?? ""),
    input: isObject(value.input) ? value.input : {},
  };
}

function parseDsml(content: string): ParsedToolCall | null {
  if (!content.includes("<｜｜DSML｜｜")) return null;
  if (!content.includes("<｜｜DSML｜｜tool_calls>")) {
    const match = content.match(DSML_SINGULAR);
    if (!match) return null;
    return {
      callId: "",
      name: match[1],
      operation: "",
      resource: "",
      risk: "",
      reason: "",
      idempotencyKey: "",
      input: parseInputJson(match[2]) ?? { content: match[2].trim() },
    };
  }
  const invoke = content.match(DSML_INVOKE);
  if (!invoke) return null;
  const input: Record<string, unknown> = {};
  for (const match of content.matchAll(DSML_PARAM)) {
    const raw = (match[3] ?? "").trim();
    try {
      input[match[1]] = JSON.parse(raw);
    } catch {
      input[match[1]] = raw;
    }
  }
  return {
    callId: "",
    name: invoke[1],
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parseXml(content: string): ParsedToolCall | null {
  const matches = [...content.matchAll(XML_TOOL)];
  if (!matches.length) return null;
  const match = matches[matches.length - 1];
  const input = parseInputJson(match[2]);
  if (!input) return null;
  return {
    callId: "",
    name: match[1],
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parseInvoke(content: string): ParsedToolCall | null {
  if (!content.includes("<tool_call_invoke>")) return null;
  const name = content.match(INVOKE_NAME);
  if (!name) return null;
  let raw = "";
  const attr = content.match(INVOKE_ATTR);
  if (attr) raw = (attr[1] ?? "").replace(/\\"/g, '"');
  else {
    const body = content.match(INVOKE_BODY);
    if (body) raw = body[1] ?? "";
  }
  const input = raw.trim() ? parseInputJson(raw) : {};
  if (!input) return null;
  return {
    callId: "",
    name: name[1].trim(),
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parseTag(content: string): ParsedToolCall | null {
  const matches = [...content.matchAll(TAG_TOOL)];
  if (!matches.length) return null;
  const match = matches[matches.length - 1];
  const input = parseInputJson(match[2]);
  if (!input) return null;
  return {
    callId: "",
    name: match[1],
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parseTodo(content: string): ParsedToolCall | null {
  if (!content.includes("<todo_")) return null;
  const match = content.match(TODO);
  if (!match) return null;
  const raw = match[2].trim();
  let input: Record<string, unknown>;
  try {
    const parsed = JSON.parse(raw);
    input = isObject(parsed) ? parsed : { content: raw };
  } catch {
    input = { content: raw };
  }
  return {
    callId: "",
    name: `todo.${match[1]}`,
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parseSkillInstall(content: string): ParsedToolCall | null {
  if (!content.includes("<skill.install")) return null;
  const match = content.match(SKILL);
  if (!match) return null;
  const input: Record<string, unknown> = {};
  for (const pair of match[1].trim().split(" ")) {
    if (!pair) continue;
    const index = pair.indexOf("=");
    if (index < 0) continue;
    const key = pair.slice(0, index).replace(/"/g, "");
    const value = pair
      .slice(index + 1)
      .replace(/^[ "\s]+|[ "\s\\]+$/g, "");
    input[key] = value;
  }
  if (!input.url) input.name = match[2].trim();
  return {
    callId: "",
    name: "skill.install",
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function parsePlain(content: string): ParsedToolCall | null {
  const matches = [...content.matchAll(PLAIN_TOOL)];
  if (!matches.length) return null;
  const match = matches[matches.length - 1];
  if (!match[1].includes(".")) return null;
  const input = parseInputJson(match[2]);
  if (!input) return null;
  return {
    callId: "",
    name: match[1],
    operation: "",
    resource: "",
    risk: "",
    reason: "",
    idempotencyKey: "",
    input,
  };
}

function withId(call: ParsedToolCall): ParsedToolCall {
  call.callId = `tc-${randomUUID().replace(/-/g, "").slice(0, 16)}`;
  return call;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
