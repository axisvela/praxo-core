use std::path::{Path, PathBuf};

use serde_json::{Map, Value};

use crate::errors::{PraxoError, Result};

#[derive(Debug, Clone)]
pub struct Action {
    pub kind: String,
    pub session_id: String,
    pub tool_name: Option<String>,
    pub arguments: Option<Map<String, Value>>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Decision {
    pub allowed: bool,
    pub reason: String,
}

impl Decision {
    pub fn allow(reason: impl Into<String>) -> Self {
        Self {
            allowed: true,
            reason: reason.into(),
        }
    }

    pub fn deny(reason: impl Into<String>) -> Self {
        Self {
            allowed: false,
            reason: reason.into(),
        }
    }
}

pub trait Hook: Send + Sync {
    fn authorize(&self, action: &Action) -> Result<Decision>;
}

#[derive(Debug, Clone)]
pub struct PathGrant {
    pub root: String,
    pub access: String,
}

pub struct PathChecker {
    grants: Vec<PathGrant>,
}

const ACCESS: [&str; 3] = ["read", "write", "readwrite"];

impl PathChecker {
    pub fn new(grants: Vec<PathGrant>) -> Result<Self> {
        let mut resolved = Vec::new();
        for grant in grants {
            if grant.root.is_empty() {
                return Err(PraxoError::policy(
                    "policy: path grant root is required",
                ));
            }
            if !ACCESS.contains(&grant.access.as_str()) {
                return Err(PraxoError::policy(format!(
                    "policy: invalid grant access {}",
                    grant.access
                )));
            }
            resolved.push(PathGrant {
                root: resolve(&grant.root)?.to_string_lossy().to_string(),
                access: grant.access,
            });
        }
        Ok(Self { grants: resolved })
    }

    pub fn check(&self, target: &str, need: &str) -> Result<Decision> {
        if !ACCESS.contains(&need) {
            return Err(PraxoError::policy(format!(
                "policy: invalid requested access {need}"
            )));
        }
        if self.grants.is_empty() {
            return Ok(Decision::deny("no allowed roots"));
        }
        let resolved = resolve(target)?.to_string_lossy().to_string();
        let mut matched = String::new();
        for grant in &self.grants {
            if !within(&grant.root, &resolved) {
                continue;
            }
            matched = grant.root.clone();
            if allows(&grant.access, need) {
                return Ok(Decision::allow(format!("path within {}", grant.root)));
            }
        }
        if !matched.is_empty() {
            return Ok(Decision::deny(format!(
                "path within {matched} but the grant is insufficient"
            )));
        }
        Ok(Decision::deny("path outside allowed roots"))
    }

    pub fn allowed(&self, target: &str, need: &str) -> bool {
        self.check(target, need)
            .map(|decision| decision.allowed)
            .unwrap_or(false)
    }
}

fn resolve(value: &str) -> Result<PathBuf> {
    let path = Path::new(value)
        .to_path_buf();
    match path.canonicalize() {
        Ok(real) => return Ok(real),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => {
            return Err(PraxoError::policy(format!(
                "policy: resolve {value}: {error}"
            )))
        }
    }
    let absolute = if path.is_absolute() {
        path
    } else {
        std::env::current_dir()
            .map_err(|error| PraxoError::policy(format!("policy: resolve {value}: {error}")))?
            .join(path)
    };
    let mut current = absolute.clone();
    let mut suffix = Vec::new();
    loop {
        let Some(parent) = current.parent() else {
            return Ok(absolute);
        };
        suffix.insert(0, current.file_name().unwrap_or_default().to_os_string());
        current = parent.to_path_buf();
        match current.canonicalize() {
            Ok(real) => {
                let mut resolved = real;
                for part in suffix {
                    resolved.push(part);
                }
                return Ok(resolved);
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => {
                return Err(PraxoError::policy(format!(
                    "policy: resolve {value}: {error}"
                )))
            }
        }
    }
}

fn within(root: &str, target: &str) -> bool {
    let normalize = |value: &str| {
        let path = Path::new(value);
        let text = path.to_string_lossy().to_string();
        if cfg!(windows) {
            text.to_lowercase()
        } else {
            text
        }
    };
    let root_value = normalize(root);
    let target_value = normalize(target);
    let prefix = format!("{root_value}{}", std::path::MAIN_SEPARATOR);
    target_value == root_value || target_value.starts_with(&prefix)
}

fn allows(grant: &str, need: &str) -> bool {
    match need {
        "read" => grant == "read" || grant == "readwrite",
        "write" => grant == "write" || grant == "readwrite",
        _ => grant == "readwrite",
    }
}
