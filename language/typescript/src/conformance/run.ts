import * as fs from "node:fs";
import * as path from "node:path";
import { isDeepStrictEqual } from "node:util";

import {
  Allowlist,
  ContextBudget,
  Event,
  FilterSink,
  MemoryStore,
  MemoryRecord,
  MultiSink,
  PathAccess,
  PathChecker,
  PluginError,
  PolicyError,
  Sink,
  STREAM_KINDS,
  TypeNotAllowedError,
  estimateTokens,
  messageFromWire,
  messageToWire,
  parseManifest,
  parseToolCall,
  stripToolCallMarkup,
  validate,
} from "../index";
import { runAgentLoop } from "./agent_loop";
import { runMiddleware } from "./middleware";
import { checkParity } from "./parity";

export interface Vector {
  id: string;
  description?: string;
  input: Record<string, unknown>;
  expect: Record<string, unknown>;
}

export interface VectorFile {
  specVersion: string;
  group: string;
  vectors: Vector[];
}

export interface VectorFailure {
  vectorId: string;
  group: string;
  detail: string;
}

const REQUIRED_GROUPS = [
  "agent-loop",
  "checkpoint",
  "context",
  "event",
  "jsonschema",
  "memory",
  "middleware",
  "plugin",
  "policy",
  "stream",
  "toolcall",
] as const;

export function repoRoot(): string {
  return path.resolve(__dirname, "../../../..");
}

export async function runAll(root = repoRoot()): Promise<VectorFailure[]> {
  const specDir = path.join(root, "spec");
  const version = fs
    .readFileSync(path.join(specDir, "SPEC_VERSION"), "utf8")
    .trim();
  const files = fs
    .readdirSync(path.join(specDir, "vectors"))
    .filter((name) => name.endsWith(".json"))
    .sort();
  const failures: VectorFailure[] = [];
  const seen = new Map<string, string>();
  const seenGroups = new Set<string>();
  for (const name of files) {
    const file = JSON.parse(
      fs.readFileSync(path.join(specDir, "vectors", name), "utf8")
    ) as VectorFile;
    seenGroups.add(file.group || name.replace(/\.json$/, ""));
    if (file.specVersion !== version) {
      failures.push({
        vectorId: name,
        group: file.group,
        detail: `specVersion ${JSON.stringify(file.specVersion)}, want ${version}`,
      });
    }
    if (file.group !== name.replace(/\.json$/, "")) {
      failures.push({
        vectorId: name,
        group: file.group,
        detail: `group mismatch`,
      });
    }
    if (!(REQUIRED_GROUPS as readonly string[]).includes(file.group)) {
      failures.push({
        vectorId: name,
        group: file.group,
        detail: "unexpected vector group",
      });
    }
    if (!Array.isArray(file.vectors) || file.vectors.length === 0) {
      failures.push({
        vectorId: name,
        group: file.group,
        detail: "vector group is empty",
      });
      continue;
    }
    for (const vector of file.vectors) {
      const previous = seen.get(vector.id);
      if (previous) {
        failures.push({
          vectorId: vector.id,
          group: file.group,
          detail: `duplicate id also used by ${previous}`,
        });
      }
      seen.set(vector.id, file.group);
      if (!(REQUIRED_GROUPS as readonly string[]).includes(file.group)) {
        continue;
      }
      try {
        await runVector(file.group, vector);
      } catch (error) {
        failures.push({
          vectorId: vector.id,
          group: file.group,
          detail: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
  for (const group of REQUIRED_GROUPS) {
    if (!seenGroups.has(group)) {
      failures.push({
        vectorId: group,
        group,
        detail: "missing required vector group",
      });
    }
  }
  return failures;
}

export async function runVector(
  group: string,
  vector: Vector
): Promise<void> {
  switch (group) {
    case "toolcall":
      return runToolcall(vector);
    case "jsonschema":
      return runJsonschema(vector);
    case "plugin":
      return runPlugin(vector);
    case "memory":
      return runMemory(vector);
    case "event":
      return runEvent(vector);
    case "stream":
      return runStream(vector);
    case "checkpoint":
      return runCheckpoint(vector);
    case "policy":
      return runPolicy(vector);
    case "context":
      return runContext(vector);
    case "middleware":
      return runMiddleware(vector);
    case "agent-loop":
      return runAgentLoop(vector);
    default:
      throw new Error(`no runner for group ${JSON.stringify(group)}`);
  }
}

function runToolcall(vector: Vector): void {
  const input = vector.input;
  if (input.operation === "strip") {
    const got = stripToolCallMarkup(String(input.content ?? ""));
    expect(got === vector.expect.text, `strip: got ${JSON.stringify(got)}`);
    return;
  }
  const call = parseToolCall(String(input.content ?? ""));
  if (vector.expect.nil) {
    expect(call === null, `expected nil, got ${JSON.stringify(call)}`);
    return;
  }
  expect(call !== null, "expected a tool call, got nil");
  expect(
    call?.name === vector.expect.name,
    `name: got ${JSON.stringify(call?.name)}`
  );
  expect(
    isDeepStrictEqual(call?.input ?? {}, vector.expect.input ?? {}),
    `input: got ${JSON.stringify(call?.input)}`
  );
}

function runJsonschema(vector: Vector): void {
  const errors = validate(
    (vector.input.schema as Record<string, unknown>) ?? {},
    vector.input.data
  );
  const got = errors.map((item) => item.path).sort();
  const want = ((vector.expect.errorPaths as string[]) ?? []).slice().sort();
  expect(
    (errors.length === 0) === Boolean(vector.expect.valid),
    `valid: got ${errors.length === 0}, want ${String(vector.expect.valid)}`
  );
  expect(
    isDeepStrictEqual(got, want),
    `errorPaths: got ${JSON.stringify(got)} want ${JSON.stringify(want)}`
  );
}

function runPlugin(vector: Vector): void {
  const input = vector.input;
  const raw =
    input.raw !== undefined
      ? String(input.raw)
      : JSON.stringify(input.manifest ?? {});
  let manifest: ReturnType<typeof parseManifest> | null = null;
  try {
    manifest = parseManifest(raw);
  } catch (error) {
    if (!(error instanceof PluginError)) throw error;
  }
  expect(
    (manifest !== null) === Boolean(vector.expect.valid),
    `valid: got ${manifest !== null}`
  );
  if (!manifest) return;
  if (vector.expect.id) {
    expect(
      manifest.id === vector.expect.id,
      `id: got ${JSON.stringify(manifest.id)}`
    );
  }
  if (vector.expect.kind) {
    expect(
      manifest.kind === vector.expect.kind,
      `kind: got ${JSON.stringify(manifest.kind)}`
    );
  }
}

async function runMemory(vector: Vector): Promise<void> {
  const store = new MemoryStore();
  for (const item of (vector.input.puts as Record<string, unknown>[]) ?? []) {
    await store.put(
      String(item.session ?? ""),
      item.record as unknown as MemoryRecord
    );
  }
  const records = await store.search(
    String(vector.input.session ?? ""),
    String(vector.input.query ?? ""),
    Number(vector.input.limit ?? 0)
  );
  const ids = records.map((record) => record.id);
  const contents = records.map((record) => record.content);
  expect(
    isDeepStrictEqual(ids.length ? ids : null, vector.expect.ids ?? null),
    `ids: got ${JSON.stringify(ids)}`
  );
  expect(
    isDeepStrictEqual(
      contents.length ? contents : null,
      vector.expect.contents ?? null
    ),
    `contents: got ${JSON.stringify(contents)}`
  );
}

class RecordingSink implements Sink {
  readonly types: string[] = [];

  async emit(event: Event): Promise<void> {
    this.types.push(event.type);
  }
}

async function runEvent(vector: Vector): Promise<void> {
  const input = vector.input;
  const events: Event[] = ((input.events as string[]) ?? []).map((type) => ({
    type,
    sessionId: "s1",
    at: new Date(0).toISOString(),
  }));
  if ((input.sink ?? "filter") === "multi") {
    const count = Math.max(1, Number(input.sinkCount ?? 1));
    const sinks = Array.from({ length: count }, () => new RecordingSink());
    const multi = new MultiSink(sinks);
    for (const event of events) await multi.emit(event);
    const got = sinks.map((sink) => sink.types.length ? sink.types : null);
    expect(
      isDeepStrictEqual(got, vector.expect.perSink ?? []),
      `perSink: got ${JSON.stringify(got)}`
    );
    return;
  }
  const rec = new RecordingSink();
  let predicate: ((event: Event) => boolean) | undefined;
  if (Array.isArray(input.predicateTypes)) {
    const allowed = new Set(input.predicateTypes as string[]);
    predicate = (event: Event): boolean => allowed.has(event.type);
  }
  const filter = new FilterSink(rec, predicate);
  for (const event of events) await filter.emit(event);
  const got = rec.types.length ? rec.types : null;
  expect(
    isDeepStrictEqual(got, vector.expect.delivered ?? null),
    `delivered: got ${JSON.stringify(got)}`
  );
}

function runStream(vector: Vector): void {
  expect(
    isDeepStrictEqual([...STREAM_KINDS], vector.expect.kinds ?? []),
    `kinds: got ${JSON.stringify(STREAM_KINDS)}`
  );
}

async function runCheckpoint(vector: Vector): Promise<void> {
  const input = vector.input;
  const allow = new Allowlist();
  for (const name of (input.registered as string[]) ?? []) {
    allow.register(name, () => ({}));
  }
  const operation = String(input.operation ?? "roundtrip");
  if (operation === "roundtrip") {
    const data = allow.marshal(String(input.type ?? ""), input.value);
    const got = allow.unmarshal(data);
    expect(
      isDeepStrictEqual(got, vector.expect.value),
      `value: got ${JSON.stringify(got)}`
    );
    return;
  }
  try {
    if (operation === "marshal") {
      allow.marshal(String(input.type ?? ""), input.value);
    } else if (operation === "unmarshal") {
      allow.unmarshal(
        JSON.stringify({ type: input.type ?? "", data: input.value })
      );
    } else {
      throw new Error(`unknown checkpoint operation ${JSON.stringify(operation)}`);
    }
  } catch (error) {
    expect(
      error instanceof TypeNotAllowedError &&
        error.code === vector.expect.errorCode,
      `errorCode: got ${String((error as { code?: string }).code)}`
    );
    return;
  }
  expect(vector.expect.errorCode === undefined, "expected an error");
}

async function runPolicy(vector: Vector): Promise<void> {
  const input = vector.input;
  const base = fs.mkdtempSync(path.join(process.env.TEMP ?? ".", "praxo-policy-"));
  try {
    for (const dir of (input.makeDirs as string[]) ?? []) {
      fs.mkdirSync(path.join(base, dir), { recursive: true });
    }
    const grants = ((input.grants as Record<string, unknown>[]) ?? []).map(
      (grant) => {
        const root = path.join(base, String(grant.root ?? ""));
        fs.mkdirSync(root, { recursive: true });
        return {
          root,
          access: String(grant.access ?? "read") as PathAccess,
        };
      }
    );
    const need = String(input.need ?? "read") as PathAccess;
    const target = path.join(base, String(input.target ?? ""));
    if (vector.expect.error) {
      try {
        new PathChecker(grants).check(target, need);
      } catch (error) {
        if (error instanceof PolicyError) return;
        throw error;
      }
      throw new Error("expected a policy error");
    }
    const decision = new PathChecker(grants).check(target, need);
    expect(
      decision.allowed === Boolean(vector.expect.allowed),
      `allowed: got ${decision.allowed}`
    );
  } finally {
    fs.rmSync(base, { recursive: true, force: true });
  }
}

function runContext(vector: Vector): void {
  const input = vector.input;
  const messages = (
    (input.messages as Record<string, unknown>[]) ?? []
  ).map(messageFromWire);
  if (input.operation === "estimate") {
    const got = estimateTokens(messages);
    expect(got === vector.expect.tokens, `tokens: got ${got}`);
    return;
  }
  const budgetInput = (input.budget as Record<string, unknown>) ?? {};
  const budget = new ContextBudget(
    Number(budgetInput.maxTokens ?? 0),
    Number(budgetInput.keepRecent ?? 0)
  );
  const [out, ok] = budget.compact(messages);
  expect(ok === Boolean(vector.expect.ok), `ok: got ${ok}`);
  if (!ok) return;
  const got = estimateTokens(out);
  expect(got === vector.expect.tokens, `tokens: got ${got}`);
  const wire = out.map(messageToWire);
  expect(
    isDeepStrictEqual(wire, vector.expect.messages),
    `messages: got ${JSON.stringify(wire)}`
  );
}

export function expect(condition: boolean, detail: string): void {
  if (!condition) throw new Error(detail);
}

async function main(): Promise<void> {
  const failures = await runAll();
  const parity = checkParity();
  for (const failure of failures) {
    console.log(
      `${failure.group}/${failure.vectorId}: ${failure.detail}`
    );
  }
  for (const failure of parity) {
    console.log(`parity: ${failure}`);
  }
  if (!failures.length && !parity.length) {
    console.log("all spec vectors and TypeScript parity checks passed");
    return;
  }
  console.log(
    `${failures.length} vector(s) failed, ${parity.length} parity gap(s)`
  );
  process.exitCode = 1;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
