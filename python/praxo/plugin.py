from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from typing import Any

from .errors import PluginError

KINDS = frozenset(
    {
        "tool.provider.v1",
        "model.provider.v1",
        "policy.provider.v1",
        "memory.provider.v1",
        "sandbox.provider.v1",
    }
)

STATES = (
    "FETCHED",
    "VALIDATED",
    "LOADED",
    "ACTIVE",
    "DRAINING",
    "STOPPED",
    "UNLOADED",
    "FAILED",
    "QUARANTINED",
)

EVENT_KINDS = (
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
)

CALL_ERROR_CODES = (
    "CAPABILITY_DENIED",
    "NOT_ACTIVE",
    "NOT_FOUND",
    "INVALID_REQUEST",
    "TIMEOUT",
    "INTERNAL",
)

_REVERSE_DNS = re.compile(
    r"^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"
)
_SEMVER = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
_ENV_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

_TOP_KEYS = {
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
}
_ENTRYPOINT_KEYS = {"type", "command", "module", "image", "args", "dir"}
_PERMISSION_KEYS = {"filesystem", "network", "env"}
_FILESYSTEM_KEYS = {"path", "mode"}
_NETWORK_KEYS = {"host", "port"}
_LIMIT_KEYS = {"memoryMB", "cpuMillis", "timeoutMs", "maxInflight"}
_HEALTH_KEYS = {"method", "intervalMs"}
_SIGNATURE_KEYS = {"algorithm", "keyId"}


@dataclass
class Manifest:
    schema_version: int
    id: str
    version: str
    kind: str
    entrypoint: dict[str, Any]
    protocol: str
    capabilities: list[str] = field(default_factory=list)
    permissions: dict[str, Any] = field(default_factory=dict)
    limits: dict[str, Any] = field(default_factory=dict)
    isolation: str = ""
    health: dict[str, Any] = field(default_factory=dict)
    signature: dict[str, Any] | None = None
    sbom: str = ""


def parse_manifest(data: bytes | str) -> Manifest:
    if isinstance(data, bytes):
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise PluginError(f"plugin: manifest: {exc}") from exc
    else:
        text = data
    if not text.strip():
        raise PluginError("plugin: manifest is empty")
    decoder = json.JSONDecoder()
    try:
        raw, index = decoder.raw_decode(text)
    except ValueError as exc:
        raise PluginError(f"plugin: manifest: {exc}") from exc
    if text[index:].strip():
        raise PluginError("plugin: manifest: trailing data")
    if not isinstance(raw, dict):
        raise PluginError("plugin: manifest must be an object")
    _check_keys(raw, _TOP_KEYS, "manifest")

    schema_version = _int(raw.get("schemaVersion"), "schemaVersion")
    if schema_version != 1:
        raise PluginError(
            f"plugin: manifest: schemaVersion = {schema_version}, want 1"
        )
    identifier = _str(raw.get("id"), "id")
    if not _REVERSE_DNS.match(identifier):
        raise PluginError(f"plugin: manifest: id {identifier!r} is not reverse-DNS")
    version = _str(raw.get("version"), "version")
    if not _SEMVER.match(version):
        raise PluginError(f"plugin: manifest: version {version!r} is not semver")
    kind = _str(raw.get("kind"), "kind")
    if kind not in KINDS:
        raise PluginError(f"plugin: manifest: kind {kind!r} is not a known contract")
    protocol = _str(raw.get("protocol"), "protocol")
    if protocol != "jsonrpc-2":
        raise PluginError(
            f"plugin: manifest: protocol = {protocol!r}, want jsonrpc-2"
        )

    entrypoint = _dict(raw.get("entrypoint"), "entrypoint")
    _check_keys(entrypoint, _ENTRYPOINT_KEYS, "entrypoint")
    entry_type = _str(entrypoint.get("type"), "entrypoint.type")
    if entry_type == "process":
        if not entrypoint.get("command"):
            raise PluginError("plugin: manifest: process entrypoint requires command")
    elif entry_type == "wasm":
        if not entrypoint.get("module"):
            raise PluginError("plugin: manifest: wasm entrypoint requires module")
    elif entry_type == "container":
        if not entrypoint.get("image"):
            raise PluginError("plugin: manifest: container entrypoint requires image")
    else:
        raise PluginError(
            f"plugin: manifest: unknown entrypoint type {entry_type!r}"
        )

    isolation = _str(raw.get("isolation"), "isolation")
    if isolation != entry_type:
        raise PluginError(
            f"plugin: manifest: isolation {isolation!r} does not match "
            f"entrypoint {entry_type!r}"
        )

    permissions = _dict(raw.get("permissions", {}), "permissions")
    _check_keys(permissions, _PERMISSION_KEYS, "permissions")
    _validate_permissions(permissions)

    limits = _dict(raw.get("limits", {}), "limits")
    _check_keys(limits, _LIMIT_KEYS, "limits")
    for key, value in limits.items():
        if _int(value, f"limits.{key}") < 0:
            raise PluginError("plugin: manifest: limits must not be negative")

    health = _dict(raw.get("health", {}), "health")
    _check_keys(health, _HEALTH_KEYS, "health")
    interval = _int(health.get("intervalMs", 0), "health.intervalMs")
    if interval < 0:
        raise PluginError("plugin: manifest: health interval must not be negative")
    if interval > 0 and not health.get("method"):
        raise PluginError("plugin: manifest: health interval requires method")

    signature_raw = raw.get("signature")
    signature: dict[str, Any] | None = None
    if signature_raw is not None:
        signature = _dict(signature_raw, "signature")
        _check_keys(signature, _SIGNATURE_KEYS, "signature")
        if not signature.get("algorithm") or not signature.get("keyId"):
            raise PluginError(
                "plugin: manifest: signature requires algorithm and keyId"
            )

    sbom = _str(raw.get("sbom", ""), "sbom")
    if sbom:
        _validate_relative_path(sbom)

    capabilities = _str_list(raw.get("capabilities", []), "capabilities")
    seen: set[str] = set()
    for capability in capabilities:
        if not capability:
            raise PluginError("plugin: manifest: capability must not be empty")
        if capability in seen:
            raise PluginError(
                f"plugin: manifest: duplicate capability {capability!r}"
            )
        seen.add(capability)

    return Manifest(
        schema_version=schema_version,
        id=identifier,
        version=version,
        kind=kind,
        entrypoint=entrypoint,
        protocol=protocol,
        capabilities=capabilities,
        permissions=permissions,
        limits=limits,
        isolation=isolation,
        health=health,
        signature=signature,
        sbom=sbom,
    )


def validate_trust(manifest: Manifest, profile: str) -> None:
    if profile == "signed":
        if manifest.signature is None:
            raise PluginError(
                "plugin: manifest: signed trust profile requires a signature"
            )
        if not manifest.sbom:
            raise PluginError(
                "plugin: manifest: signed trust profile requires an sbom"
            )
        return
    if profile == "unsigned":
        return
    raise PluginError(f"plugin: manifest: unknown trust profile {profile!r}")


def _validate_permissions(permissions: dict[str, Any]) -> None:
    filesystem = permissions.get("filesystem", [])
    for index, item in enumerate(_list(filesystem, "permissions.filesystem")):
        entry = _dict(item, f"permissions.filesystem[{index}]")
        _check_keys(entry, _FILESYSTEM_KEYS, "filesystem")
        if not entry.get("path"):
            raise PluginError(
                "plugin: manifest: filesystem permission requires path"
            )
        if entry.get("mode") not in ("read", "write", "readwrite"):
            raise PluginError(
                f"plugin: manifest: filesystem mode {entry.get('mode')!r} "
                "is not read, write, or readwrite"
            )
    network = permissions.get("network", [])
    for index, item in enumerate(_list(network, "permissions.network")):
        entry = _dict(item, f"permissions.network[{index}]")
        _check_keys(entry, _NETWORK_KEYS, "network")
        if not entry.get("host"):
            raise PluginError("plugin: manifest: network permission requires host")
        port = _int(entry.get("port"), "permissions.network.port")
        if port < 1 or port > 65535:
            raise PluginError(
                f"plugin: manifest: network port {port} is out of range"
            )
    for name in _str_list(permissions.get("env", []), "permissions.env"):
        if not _ENV_NAME.match(name):
            raise PluginError(f"plugin: manifest: env name {name!r} is invalid")


def _validate_relative_path(value: str) -> None:
    normalized = value.replace("\\", "/")
    if normalized.startswith("/") or os.path.isabs(value):
        raise PluginError("plugin: manifest: sbom path must be relative")
    for part in normalized.split("/"):
        if part == "..":
            raise PluginError("plugin: manifest: sbom path must not contain '..'")


def _check_keys(value: dict[str, Any], allowed: set[str], where: str) -> None:
    for key in value:
        if key not in allowed:
            raise PluginError(f"plugin: manifest: unknown field {key!r} in {where}")


def _dict(value: Any, where: str) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise PluginError(f"plugin: manifest: {where} must be an object")
    return value


def _list(value: Any, where: str) -> list[Any]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise PluginError(f"plugin: manifest: {where} must be an array")
    return value


def _str_list(value: Any, where: str) -> list[str]:
    items = _list(value, where)
    out: list[str] = []
    for item in items:
        if not isinstance(item, str):
            raise PluginError(f"plugin: manifest: {where} must contain strings")
        out.append(item)
    return out


def _str(value: Any, where: str) -> str:
    if not isinstance(value, str):
        raise PluginError(f"plugin: manifest: {where} must be a string")
    return value


def _int(value: Any, where: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise PluginError(f"plugin: manifest: {where} must be an integer")
    return value
