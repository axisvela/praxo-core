import * as path from "node:path";

import { PluginError } from "./errors";

export const KINDS = new Set([
  "tool.provider.v1",
  "model.provider.v1",
  "policy.provider.v1",
  "memory.provider.v1",
  "sandbox.provider.v1",
]);

export const STATES = [
  "FETCHED",
  "VALIDATED",
  "LOADED",
  "ACTIVE",
  "DRAINING",
  "STOPPED",
  "UNLOADED",
  "FAILED",
  "QUARANTINED",
] as const;

export const EVENT_KINDS = [
  "start",
  "success",
  "failure",
  "stop",
  "crash",
  "verification_denied",
  "registration_denied",
  "authorization_denied",
  "resource_limit",
  "canceled",
  "terminated",
] as const;

export const CALL_ERROR_CODES = [
  "CAPABILITY_DENIED",
  "NOT_ACTIVE",
  "NOT_FOUND",
  "INVALID_REQUEST",
  "TIMEOUT",
  "INTERNAL",
] as const;

const REVERSE_DNS =
  /^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/;
const SEMVER =
  /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

const TOP_KEYS = new Set([
  "schemaVersion",
  "id",
  "version",
  "kind",
  "entrypoint",
  "protocol",
  "capabilities",
  "permissions",
  "limits",
  "isolation",
  "health",
  "signature",
  "sbom",
]);
const ENTRYPOINT_KEYS = new Set([
  "type",
  "command",
  "module",
  "image",
  "args",
  "dir",
]);
const PERMISSION_KEYS = new Set(["filesystem", "network", "env"]);
const FILESYSTEM_KEYS = new Set(["path", "mode"]);
const NETWORK_KEYS = new Set(["host", "port"]);
const LIMIT_KEYS = new Set([
  "memoryMB",
  "cpuMillis",
  "timeoutMs",
  "maxInflight",
]);
const HEALTH_KEYS = new Set(["method", "intervalMs"]);
const SIGNATURE_KEYS = new Set(["algorithm", "keyId"]);

export interface Manifest {
  schemaVersion: number;
  id: string;
  version: string;
  kind: string;
  entrypoint: Record<string, unknown>;
  protocol: string;
  capabilities: string[];
  permissions: Record<string, unknown>;
  limits: Record<string, unknown>;
  isolation: string;
  health: Record<string, unknown>;
  signature?: Record<string, unknown>;
  sbom: string;
}

export function parseManifest(raw: string | Buffer): Manifest {
  const text = Buffer.isBuffer(raw) ? raw.toString("utf8") : raw;
  if (!text.trim()) throw new PluginError("plugin: manifest is empty");
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch (error) {
    throw new PluginError(`plugin: manifest: ${String(error)}`);
  }
  if (!isObject(value)) {
    throw new PluginError("plugin: manifest must be an object");
  }
  checkKeys(value, TOP_KEYS, "manifest");

  const schemaVersion = asInt(value.schemaVersion, "schemaVersion");
  if (schemaVersion !== 1) {
    throw new PluginError(
      `plugin: manifest: schemaVersion = ${schemaVersion}, want 1`
    );
  }
  const id = asString(value.id, "id");
  if (!REVERSE_DNS.test(id)) {
    throw new PluginError(
      `plugin: manifest: id ${JSON.stringify(id)} is not reverse-DNS`
    );
  }
  const version = asString(value.version, "version");
  if (!SEMVER.test(version)) {
    throw new PluginError(
      `plugin: manifest: version ${JSON.stringify(version)} is not semver`
    );
  }
  const kind = asString(value.kind, "kind");
  if (!KINDS.has(kind)) {
    throw new PluginError(
      `plugin: manifest: kind ${JSON.stringify(kind)} is not a known contract`
    );
  }
  const protocol = asString(value.protocol, "protocol");
  if (protocol !== "jsonrpc-2") {
    throw new PluginError(
      `plugin: manifest: protocol = ${JSON.stringify(protocol)}, want jsonrpc-2`
    );
  }

  const entrypoint = asObject(value.entrypoint, "entrypoint");
  checkKeys(entrypoint, ENTRYPOINT_KEYS, "entrypoint");
  const entryType = asString(entrypoint.type, "entrypoint.type");
  if (entryType === "process") {
    if (!entrypoint.command) {
      throw new PluginError(
        "plugin: manifest: process entrypoint requires command"
      );
    }
  } else if (entryType === "wasm") {
    if (!entrypoint.module) {
      throw new PluginError(
        "plugin: manifest: wasm entrypoint requires module"
      );
    }
  } else if (entryType === "container") {
    if (!entrypoint.image) {
      throw new PluginError(
        "plugin: manifest: container entrypoint requires image"
      );
    }
  } else {
    throw new PluginError(
      `plugin: manifest: unknown entrypoint type ${JSON.stringify(entryType)}`
    );
  }

  const isolation = asString(value.isolation, "isolation");
  if (isolation !== entryType) {
    throw new PluginError(
      `plugin: manifest: isolation ${JSON.stringify(isolation)} does not ` +
        `match entrypoint ${JSON.stringify(entryType)}`
    );
  }

  const permissions = asObject(value.permissions ?? {}, "permissions");
  checkKeys(permissions, PERMISSION_KEYS, "permissions");
  validatePermissions(permissions);

  const limits = asObject(value.limits ?? {}, "limits");
  checkKeys(limits, LIMIT_KEYS, "limits");
  for (const [key, item] of Object.entries(limits)) {
    if (asInt(item, `limits.${key}`) < 0) {
      throw new PluginError(
        "plugin: manifest: limits must not be negative"
      );
    }
  }

  const health = asObject(value.health ?? {}, "health");
  checkKeys(health, HEALTH_KEYS, "health");
  const interval = asInt(health.intervalMs ?? 0, "health.intervalMs");
  if (interval < 0) {
    throw new PluginError(
      "plugin: manifest: health interval must not be negative"
    );
  }
  if (interval > 0 && !health.method) {
    throw new PluginError(
      "plugin: manifest: health interval requires method"
    );
  }

  let signature: Record<string, unknown> | undefined;
  if (value.signature !== undefined) {
    signature = asObject(value.signature, "signature");
    checkKeys(signature, SIGNATURE_KEYS, "signature");
    if (!signature.algorithm || !signature.keyId) {
      throw new PluginError(
        "plugin: manifest: signature requires algorithm and keyId"
      );
    }
  }

  const sbom = asString(value.sbom ?? "", "sbom");
  if (sbom) validateRelativePath(sbom);

  const capabilities = asStringArray(
    value.capabilities ?? [],
    "capabilities"
  );
  const seen = new Set<string>();
  for (const capability of capabilities) {
    if (!capability) {
      throw new PluginError(
        "plugin: manifest: capability must not be empty"
      );
    }
    if (seen.has(capability)) {
      throw new PluginError(
        `plugin: manifest: duplicate capability ${JSON.stringify(capability)}`
      );
    }
    seen.add(capability);
  }

  return {
    schemaVersion,
    id,
    version,
    kind,
    entrypoint,
    protocol,
    capabilities,
    permissions,
    limits,
    isolation,
    health,
    signature,
    sbom,
  };
}

export function validateTrust(manifest: Manifest, profile: string): void {
  if (profile === "signed") {
    if (!manifest.signature) {
      throw new PluginError(
        "plugin: manifest: signed trust profile requires a signature"
      );
    }
    if (!manifest.sbom) {
      throw new PluginError(
        "plugin: manifest: signed trust profile requires an sbom"
      );
    }
    return;
  }
  if (profile === "unsigned") return;
  throw new PluginError(
    `plugin: manifest: unknown trust profile ${JSON.stringify(profile)}`
  );
}

function validatePermissions(permissions: Record<string, unknown>): void {
  for (const [index, item] of asArray(
    permissions.filesystem ?? [],
    "permissions.filesystem"
  ).entries()) {
    const entry = asObject(item, `permissions.filesystem[${index}]`);
    checkKeys(entry, FILESYSTEM_KEYS, "filesystem");
    if (!entry.path) {
      throw new PluginError(
        "plugin: manifest: filesystem permission requires path"
      );
    }
    if (
      entry.mode !== "read" &&
      entry.mode !== "write" &&
      entry.mode !== "readwrite"
    ) {
      throw new PluginError(
        `plugin: manifest: filesystem mode ${JSON.stringify(entry.mode)} ` +
          "is not read, write, or readwrite"
      );
    }
  }
  for (const [index, item] of asArray(
    permissions.network ?? [],
    "permissions.network"
  ).entries()) {
    const entry = asObject(item, `permissions.network[${index}]`);
    checkKeys(entry, NETWORK_KEYS, "network");
    if (!entry.host) {
      throw new PluginError(
        "plugin: manifest: network permission requires host"
      );
    }
    const port = asInt(entry.port, "permissions.network.port");
    if (port < 1 || port > 65535) {
      throw new PluginError(
        `plugin: manifest: network port ${port} is out of range`
      );
    }
  }
  for (const name of asStringArray(
    permissions.env ?? [],
    "permissions.env"
  )) {
    if (!ENV_NAME.test(name)) {
      throw new PluginError(
        `plugin: manifest: env name ${JSON.stringify(name)} is invalid`
      );
    }
  }
}

function validateRelativePath(value: string): void {
  const normalized = value.replace(/\\/g, "/");
  if (normalized.startsWith("/") || path.isAbsolute(value)) {
    throw new PluginError(
      "plugin: manifest: sbom path must be relative"
    );
  }
  if (normalized.split("/").includes("..")) {
    throw new PluginError(
      "plugin: manifest: sbom path must not contain '..'"
    );
  }
}

function checkKeys(
  value: Record<string, unknown>,
  allowed: Set<string>,
  where: string
): void {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new PluginError(
        `plugin: manifest: unknown field ${JSON.stringify(key)} in ${where}`
      );
    }
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asObject(value: unknown, where: string): Record<string, unknown> {
  if (value === undefined || value === null) return {};
  if (!isObject(value)) {
    throw new PluginError(
      `plugin: manifest: ${where} must be an object`
    );
  }
  return value;
}

function asArray(value: unknown, where: string): unknown[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) {
    throw new PluginError(
      `plugin: manifest: ${where} must be an array`
    );
  }
  return value;
}

function asStringArray(value: unknown, where: string): string[] {
  return asArray(value, where).map((item) => {
    if (typeof item !== "string") {
      throw new PluginError(
        `plugin: manifest: ${where} must contain strings`
      );
    }
    return item;
  });
}

function asString(value: unknown, where: string): string {
  if (typeof value !== "string") {
    throw new PluginError(
      `plugin: manifest: ${where} must be a string`
    );
  }
  return value;
}

function asInt(value: unknown, where: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new PluginError(
      `plugin: manifest: ${where} must be an integer`
    );
  }
  return value;
}
