const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const { snapshot } = require("../api-signatures");

function fixture(source) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "praxo-ts-api-"));
  fs.mkdirSync(path.join(root, "src"), { recursive: true });
  fs.writeFileSync(
    path.join(root, "package.json"),
    JSON.stringify({ version: "0.1.0" })
  );
  fs.writeFileSync(
    path.join(root, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {
        target: "ES2022",
        module: "CommonJS",
        strict: true,
        skipLibCheck: true,
      },
      include: ["src/**/*.ts"],
    })
  );
  fs.writeFileSync(path.join(root, "src", "index.ts"), source);
  return root;
}

function render(source) {
  const root = fixture(source);
  try {
    return snapshot(root, "0.2.0");
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

const base = `
export interface Item {
  name: string;
  count?: number;
  run(value: string): number;
}
export function join(left: string, right: number): string {
  return left + right;
}
export const LIMIT = 3;
`;

test("captures fields, optionality, methods, functions, and constants", () => {
  const output = render(base);
  for (const expected of [
    "interface Item",
    "name: string",
    "count?: number | undefined",
    "run(value: string): number",
    "function join",
    "join(left: string, right: number): string",
    "const LIMIT: 3",
  ]) {
    assert.ok(output.includes(expected), `${expected}\n${output}`);
  }
});

test("same-name signature and field changes alter the snapshot", () => {
  const mutations = [
    ["name: string;", "name: number;"],
    ["count?: number;", "count?: string;"],
    ["count?: number;", "count: number;"],
    ["run(value: string): number;", "run(value: number): number;"],
    ["join(left: string, right: number): string", "join(left: string, right: number): number"],
    ["export const LIMIT = 3;", "export const LIMIT = 4;"],
  ];
  for (const [before, after] of mutations) {
    assert.ok(base.includes(before), before);
    assert.notEqual(render(base), render(base.replace(before, after)), after);
  }
});

test("class constructor and method changes alter the snapshot", () => {
  const source = `
export class Thing {
  value: string;
  constructor(value: string) { this.value = value; }
  read(prefix: string): string { return prefix + this.value; }
}
`;
  const output = render(source);
  assert.ok(output.includes("constructor(value: string)"), output);
  assert.ok(output.includes("read(prefix: string): string"), output);
  assert.notEqual(render(source), render(source.replace("read(prefix: string): string", "read(prefix: number): string")));
  assert.notEqual(render(source), render(source.replace("constructor(value: string)", "constructor(value: number)")));
});
