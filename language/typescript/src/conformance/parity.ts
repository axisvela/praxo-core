import * as fs from "node:fs";
import * as path from "node:path";

import { SDK_VERSION } from "../index";

export function checkParity(root = repoRoot()): string[] {
  const snapshotPath = path.join(
    root,
    "language",
    "typescript",
    "api",
    `${SDK_VERSION}.txt`
  );
  if (!fs.existsSync(snapshotPath)) {
    return [`missing API snapshot: ${snapshotPath}`];
  }
  const names = new Set(
    fs
      .readFileSync(snapshotPath, "utf8")
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#"))
  );
  const parity = fs.readFileSync(
    path.join(root, "spec", "parity.md"),
    "utf8"
  );
  const statuses = new Map<string, string>();
  for (const line of parity.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("| `pkg/")) continue;
    const cells = trimmed.split("|");
    if (cells.length < 7) continue;
    statuses.set(strip(cells[1]), strip(cells[4]));
  }

  const failures: string[] = [];
  for (const line of parity.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("| `") || trimmed.startsWith("| `pkg/")) {
      continue;
    }
    const cells = trimmed.split("|");
    if (cells.length < 7) continue;
    const goSymbol = strip(cells[1]);
    const tsSymbol = strip(cells[4]);
    const prefix = goSymbol.slice(0, goSymbol.lastIndexOf("."));
    const pkg = prefix.startsWith("pkg/") ? prefix : `pkg/${prefix}`;
    if (statuses.get(pkg) !== "parity") continue;
    if (!tsSymbol) {
      failures.push(`${goSymbol}: empty TypeScript symbol`);
      continue;
    }
    if (!names.has(tsSymbol)) {
      failures.push(`${goSymbol}: missing ${tsSymbol}`);
    }
  }
  return failures;
}

function strip(value: string | undefined): string {
  return (value ?? "").trim().replace(/^`|`$/g, "");
}

function repoRoot(): string {
  return path.resolve(__dirname, "../../../..");
}
