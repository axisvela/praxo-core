use std::collections::HashSet;
use std::path::Path;
use std::sync::OnceLock;

use regex::Regex;
use serde_json::{Map, Value};

use crate::errors::{PraxoError, Result};

pub const KINDS: [&str; 5] = [
    "tool.provider.v1",
    "model.provider.v1",
    "policy.provider.v1",
    "memory.provider.v1",
    "sandbox.provider.v1",
];

pub const STATES: [&str; 9] = [
    "FETCHED",
    "VALIDATED",
    "LOADED",
    "ACTIVE",
    "DRAINING",
    "STOPPED",
    "UNLOADED",
    "FAILED",
    "QUARANTINED",
];

pub const EVENT_KINDS: [&str; 11] = [
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
];

#[derive(Debug, Clone)]
pub struct Manifest {
    pub schema_version: i64,
    pub id: String,
    pub version: String,
    pub kind: String,
    pub entrypoint: Map<String, Value>,
    pub protocol: String,
    pub capabilities: Vec<String>,
    pub permissions: Map<String, Value>,
    pub limits: Map<String, Value>,
    pub isolation: String,
    pub health: Map<String, Value>,
    pub signature: Option<Map<String, Value>>,
    pub sbom: String,
}

fn reverse_dns() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(r"^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
            .expect("valid regex")
    })
}

fn semver() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(
            r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$",
        )
        .expect("valid regex")
    })
}

fn env_name() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"^[A-Za-z_][A-Za-z0-9_]*$").expect("valid regex"))
}

pub fn parse_manifest(raw: &str) -> Result<Manifest> {
    if raw.trim().is_empty() {
        return Err(PraxoError::plugin("plugin: manifest is empty"));
    }
    let value: Value = serde_json::from_str(raw)
        .map_err(|error| PraxoError::plugin(format!("plugin: manifest: {error}")))?;
    let map = value
        .as_object()
        .ok_or_else(|| PraxoError::plugin("plugin: manifest must be an object"))?;
    check_keys(map, TOP_KEYS, "manifest")?;
    let schema_version = as_int(map.get("schemaVersion"), "schemaVersion")?;
    if schema_version != 1 {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: schemaVersion = {schema_version}, want 1"
        )));
    }
    let id = as_string(map.get("id"), "id")?;
    if !reverse_dns().is_match(&id) {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: id {id} is not reverse-DNS"
        )));
    }
    let version = as_string(map.get("version"), "version")?;
    if !semver().is_match(&version) {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: version {version} is not semver"
        )));
    }
    let kind = as_string(map.get("kind"), "kind")?;
    if !KINDS.contains(&kind.as_str()) {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: kind {kind} is not a known contract"
        )));
    }
    let protocol = as_string(map.get("protocol"), "protocol")?;
    if protocol != "jsonrpc-2" {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: protocol = {protocol}, want jsonrpc-2"
        )));
    }
    let entrypoint = as_object(map.get("entrypoint"), "entrypoint")?;
    check_keys(&entrypoint, ENTRYPOINT_KEYS, "entrypoint")?;
    let entry_type = as_string(entrypoint.get("type"), "entrypoint.type")?;
    match entry_type.as_str() {
        "process" => {
            if !text_present(entrypoint.get("command")) {
                return Err(PraxoError::plugin(
                    "plugin: manifest: process entrypoint requires command",
                ));
            }
        }
        "wasm" => {
            if !text_present(entrypoint.get("module")) {
                return Err(PraxoError::plugin(
                    "plugin: manifest: wasm entrypoint requires module",
                ));
            }
        }
        "container" => {
            if !text_present(entrypoint.get("image")) {
                return Err(PraxoError::plugin(
                    "plugin: manifest: container entrypoint requires image",
                ));
            }
        }
        _ => {
            return Err(PraxoError::plugin(format!(
                "plugin: manifest: unknown entrypoint type {entry_type}"
            )))
        }
    }
    let isolation = as_string(map.get("isolation"), "isolation")?;
    if isolation != entry_type {
        return Err(PraxoError::plugin(format!(
            "plugin: manifest: isolation {isolation} does not match entrypoint {entry_type}"
        )));
    }
    let permissions = as_object(map.get("permissions"), "permissions")?;
    check_keys(&permissions, PERMISSION_KEYS, "permissions")?;
    validate_permissions(&permissions)?;
    let limits = as_object(map.get("limits"), "limits")?;
    check_keys(&limits, LIMIT_KEYS, "limits")?;
    for (key, value) in &limits {
        if as_int(Some(value), &format!("limits.{key}"))? < 0 {
            return Err(PraxoError::plugin(
                "plugin: manifest: limits must not be negative",
            ));
        }
    }
    let health = as_object(map.get("health"), "health")?;
    check_keys(&health, HEALTH_KEYS, "health")?;
    let interval = health
        .get("intervalMs")
        .map(|value| as_int(Some(value), "health.intervalMs"))
        .transpose()?
        .unwrap_or(0);
    if interval < 0 {
        return Err(PraxoError::plugin(
            "plugin: manifest: health interval must not be negative",
        ));
    }
    if interval > 0 && !text_present(health.get("method")) {
        return Err(PraxoError::plugin(
            "plugin: manifest: health interval requires method",
        ));
    }
    let signature = match map.get("signature") {
        None | Some(Value::Null) => None,
        Some(value) => {
            let signature = as_object(Some(value), "signature")?;
            check_keys(&signature, SIGNATURE_KEYS, "signature")?;
            if !text_present(signature.get("algorithm"))
                || !text_present(signature.get("keyId"))
            {
                return Err(PraxoError::plugin(
                    "plugin: manifest: signature requires algorithm and keyId",
                ));
            }
            Some(signature)
        }
    };
    let sbom = map
        .get("sbom")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    if !sbom.is_empty() {
        validate_relative_path(&sbom)?;
    }
    let mut capabilities = Vec::new();
    if let Some(value) = map.get("capabilities") {
        for item in value
            .as_array()
            .ok_or_else(|| PraxoError::plugin("plugin: manifest: capabilities must be an array"))?
        {
            capabilities.push(as_string(Some(item), "capabilities")?);
        }
    }
    let mut seen = HashSet::new();
    for capability in &capabilities {
        if capability.is_empty() {
            return Err(PraxoError::plugin(
                "plugin: manifest: capability must not be empty",
            ));
        }
        if !seen.insert(capability.clone()) {
            return Err(PraxoError::plugin(format!(
                "plugin: manifest: duplicate capability {capability}"
            )));
        }
    }
    Ok(Manifest {
        schema_version,
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
    })
}

pub fn validate_trust(manifest: &Manifest, profile: &str) -> Result<()> {
    match profile {
        "signed" => {
            if manifest.signature.is_none() {
                return Err(PraxoError::plugin(
                    "plugin: manifest: signed trust profile requires a signature",
                ));
            }
            if manifest.sbom.is_empty() {
                return Err(PraxoError::plugin(
                    "plugin: manifest: signed trust profile requires an sbom",
                ));
            }
            Ok(())
        }
        "unsigned" => Ok(()),
        _ => Err(PraxoError::plugin(format!(
            "plugin: manifest: unknown trust profile {profile}"
        ))),
    }
}

fn validate_permissions(permissions: &Map<String, Value>) -> Result<()> {
    if let Some(value) = permissions.get("filesystem") {
        for item in value.as_array().ok_or_else(|| {
            PraxoError::plugin("plugin: manifest: filesystem must be an array")
        })? {
            let entry = as_object(Some(item), "filesystem")?;
            check_keys(&entry, FILESYSTEM_KEYS, "filesystem")?;
            if !text_present(entry.get("path")) {
                return Err(PraxoError::plugin(
                    "plugin: manifest: filesystem permission requires path",
                ));
            }
            let mode = entry.get("mode").and_then(Value::as_str).unwrap_or("");
            if !matches!(mode, "read" | "write" | "readwrite") {
                return Err(PraxoError::plugin(format!(
                    "plugin: manifest: filesystem mode {mode} is not read, write, or readwrite"
                )));
            }
        }
    }
    if let Some(value) = permissions.get("network") {
        for item in value.as_array().ok_or_else(|| {
            PraxoError::plugin("plugin: manifest: network must be an array")
        })? {
            let entry = as_object(Some(item), "network")?;
            check_keys(&entry, NETWORK_KEYS, "network")?;
            if !text_present(entry.get("host")) {
                return Err(PraxoError::plugin(
                    "plugin: manifest: network permission requires host",
                ));
            }
            let port = as_int(entry.get("port"), "permissions.network.port")?;
            if !(1..=65535).contains(&port) {
                return Err(PraxoError::plugin(format!(
                    "plugin: manifest: network port {port} is out of range"
                )));
            }
        }
    }
    if let Some(value) = permissions.get("env") {
        for item in value
            .as_array()
            .ok_or_else(|| PraxoError::plugin("plugin: manifest: env must be an array"))?
        {
            let name = as_string(Some(item), "permissions.env")?;
            if !env_name().is_match(&name) {
                return Err(PraxoError::plugin(format!(
                    "plugin: manifest: env name {name} is invalid"
                )));
            }
        }
    }
    Ok(())
}

fn validate_relative_path(value: &str) -> Result<()> {
    let normalized = value.replace('\\', "/");
    if normalized.starts_with('/') || Path::new(value).is_absolute() {
        return Err(PraxoError::plugin(
            "plugin: manifest: sbom path must be relative",
        ));
    }
    if normalized.split('/').any(|part| part == "..") {
        return Err(PraxoError::plugin(
            "plugin: manifest: sbom path must not contain '..'",
        ));
    }
    Ok(())
}

fn check_keys(value: &Map<String, Value>, allowed: &[&str], where_: &str) -> Result<()> {
    for key in value.keys() {
        if !allowed.contains(&key.as_str()) {
            return Err(PraxoError::plugin(format!(
                "plugin: manifest: unknown field {key} in {where_}"
            )));
        }
    }
    Ok(())
}

fn as_object(value: Option<&Value>, where_: &str) -> Result<Map<String, Value>> {
    match value {
        None | Some(Value::Null) => Ok(Map::new()),
        Some(Value::Object(map)) => Ok(map.clone()),
        _ => Err(PraxoError::plugin(format!(
            "plugin: manifest: {where_} must be an object"
        ))),
    }
}

fn as_string(value: Option<&Value>, where_: &str) -> Result<String> {
    value
        .and_then(Value::as_str)
        .map(|text| text.to_string())
        .ok_or_else(|| PraxoError::plugin(format!("plugin: manifest: {where_} must be a string")))
}

fn as_int(value: Option<&Value>, where_: &str) -> Result<i64> {
    value
        .and_then(Value::as_i64)
        .ok_or_else(|| PraxoError::plugin(format!("plugin: manifest: {where_} must be an integer")))
}

fn text_present(value: Option<&Value>) -> bool {
    value.and_then(Value::as_str).map(|text| !text.is_empty()).unwrap_or(false)
}

const TOP_KEYS: &[&str] = &[
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
];
const ENTRYPOINT_KEYS: &[&str] = &["type", "command", "module", "image", "args", "dir"];
const PERMISSION_KEYS: &[&str] = &["filesystem", "network", "env"];
const FILESYSTEM_KEYS: &[&str] = &["path", "mode"];
const NETWORK_KEYS: &[&str] = &["host", "port"];
const LIMIT_KEYS: &[&str] = &["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"];
const HEALTH_KEYS: &[&str] = &["method", "intervalMs"];
const SIGNATURE_KEYS: &[&str] = &["algorithm", "keyId"];
