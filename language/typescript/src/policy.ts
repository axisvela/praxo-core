import * as fs from "node:fs";
import * as path from "node:path";

import { PolicyError } from "./errors";

export type PathAccess = "read" | "write" | "readwrite";

export interface Action {
  kind: string;
  sessionId: string;
  toolName?: string;
  arguments?: Record<string, unknown>;
}

export interface Decision {
  allowed: boolean;
  reason?: string;
}

export interface Hook {
  authorize(action: Action): Promise<Decision> | Decision;
}

export class FuncHook implements Hook {
  constructor(
    private readonly fn: (action: Action) => Promise<Decision> | Decision
  ) {}

  authorize(action: Action): Promise<Decision> | Decision {
    return this.fn(action);
  }
}

export interface PathGrant {
  root: string;
  access: PathAccess;
}

const ACCESS = new Set<string>(["read", "write", "readwrite"]);

export class PathChecker {
  private readonly grants: PathGrant[];

  constructor(grants: PathGrant[]) {
    this.grants = grants.map((grant) => {
      if (!grant.root) {
        throw new PolicyError("policy: path grant root is required");
      }
      if (!ACCESS.has(grant.access)) {
        throw new PolicyError(
          `policy: invalid grant access ${JSON.stringify(grant.access)}`
        );
      }
      return { root: resolvePath(grant.root), access: grant.access };
    });
  }

  check(target: string, need: PathAccess = "read"): Decision {
    if (!ACCESS.has(need)) {
      throw new PolicyError(
        `policy: invalid requested access ${JSON.stringify(need)}`
      );
    }
    if (!this.grants.length) {
      return { allowed: false, reason: "no allowed roots" };
    }
    const resolved = resolvePath(target);
    let matched = "";
    for (const grant of this.grants) {
      if (!within(grant.root, resolved)) continue;
      matched = grant.root;
      if (allows(grant.access, need)) {
        return { allowed: true, reason: `path within ${grant.root}` };
      }
    }
    if (matched) {
      return {
        allowed: false,
        reason: `path within ${matched} but the grant is insufficient`,
      };
    }
    return { allowed: false, reason: "path outside allowed roots" };
  }

  allowed(target: string, need: PathAccess = "read"): boolean {
    try {
      return this.check(target, need).allowed;
    } catch {
      return false;
    }
  }
}

function resolvePath(value: string): string {
  const absolute = path.resolve(value);
  try {
    return fs.realpathSync.native(absolute);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw new PolicyError(`policy: resolve ${value}: ${String(error)}`);
    }
  }
  const suffix: string[] = [];
  let current = absolute;
  while (true) {
    const parent = path.dirname(current);
    if (parent === current) {
      return absolute;
    }
    suffix.unshift(path.basename(current));
    current = parent;
    try {
      const real = fs.realpathSync.native(current);
      return path.join(real, ...suffix);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
        throw new PolicyError(`policy: resolve ${value}: ${String(error)}`);
      }
    }
  }
}

function within(root: string, target: string): boolean {
  const normalize = (value: string): string =>
    process.platform === "win32" ? value.toLowerCase() : value;
  const rootValue = normalize(path.normalize(root));
  const targetValue = normalize(path.normalize(target));
  return (
    rootValue === targetValue ||
    targetValue.startsWith(rootValue + path.sep)
  );
}

function allows(grant: PathAccess, need: PathAccess): boolean {
  if (need === "read") return grant === "read" || grant === "readwrite";
  if (need === "write") return grant === "write" || grant === "readwrite";
  return grant === "readwrite";
}
