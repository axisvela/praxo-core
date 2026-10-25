use std::collections::HashMap;
use std::sync::Mutex;

use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};

type Factory = Box<dyn Fn() -> Value + Send + Sync>;

pub struct Allowlist {
    factories: Mutex<HashMap<String, Factory>>,
}

impl Default for Allowlist {
    fn default() -> Self {
        Self {
            factories: Mutex::new(HashMap::new()),
        }
    }
}

impl Allowlist {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn register(
        &self,
        name: &str,
        factory: impl Fn() -> Value + Send + Sync + 'static,
    ) -> Result<()> {
        if name.is_empty() {
            return Err(PraxoError::checkpoint(
                "checkpoint: allowlist type name is required",
            ));
        }
        self.factories
            .lock()
            .expect("allowlist poisoned")
            .insert(name.to_string(), Box::new(factory));
        Ok(())
    }

    pub fn marshal(&self, name: &str, value: Value) -> Result<String> {
        if !self
            .factories
            .lock()
            .expect("allowlist poisoned")
            .contains_key(name)
        {
            return Err(PraxoError::type_not_allowed(format!(
                "checkpoint: payload type not allowed: {name}"
            )));
        }
        let envelope = json!({"type": name, "data": value});
        serde_json::to_string(&envelope)
            .map_err(|error| PraxoError::checkpoint(format!("checkpoint: {error}")))
    }

    pub fn unmarshal(&self, data: &str) -> Result<Value> {
        let envelope: Map<String, Value> = serde_json::from_str(data)
            .map_err(|error| PraxoError::checkpoint(format!("checkpoint: {error}")))?;
        let name = envelope
            .get("type")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        let factory = self
            .factories
            .lock()
            .expect("allowlist poisoned")
            .get(&name)
            .map(|factory| factory())
            .ok_or_else(|| {
                PraxoError::type_not_allowed(format!(
                    "checkpoint: payload type not allowed: {name}"
                ))
            })?;
        let payload = envelope.get("data").cloned().unwrap_or(Value::Null);
        match (factory, payload) {
            (Value::Object(mut target), Value::Object(values)) => {
                target.extend(values);
                Ok(Value::Object(target))
            }
            (_, payload) => Ok(payload),
        }
    }
}
