use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

use crate::adapters::harmovela::{HttpRequest, StdTransport, Transport};
use crate::errors::{PraxoError, Result};
use crate::event::Event;

pub struct Sink {
    pub endpoint: String,
    pub service_name: String,
    pub allowed_data_keys: Vec<String>,
    transport: Arc<dyn Transport>,
}

impl Sink {
    pub fn new(endpoint: impl Into<String>) -> Self {
        Self::with_transport(endpoint, Arc::new(StdTransport))
    }

    pub fn with_transport(
        endpoint: impl Into<String>,
        transport: Arc<dyn Transport>,
    ) -> Self {
        Self {
            endpoint: endpoint.into(),
            service_name: "praxo-core".to_string(),
            allowed_data_keys: Vec::new(),
            transport,
        }
    }

    pub fn emit(&self, event: &Event) -> Result<()> {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|value| value.as_nanos())
            .unwrap_or(0);
        let data = event
            .data
            .as_ref()
            .map(|value| serde_json::to_string(value).unwrap_or_default())
            .unwrap_or_else(|| "{}".to_string());
        let key = format!(
            "{}|{}|{}|{}|{}",
            event.session_id,
            event.run_id.clone().unwrap_or_default(),
            event.kind,
            event.at.clone().unwrap_or_default(),
            data
        );
        let trace_id = format!(
            "{:016x}{:016x}",
            fnv1a(&key, 0xcbf29ce484222325),
            fnv1a(&key, 0x84222325cbf29ce4)
        );
        let span_id = format!("{:016x}", fnv1a(&format!("{key}|span"), 0x100000001b3));

        let mut attributes = vec![attribute("praxo.event.type", &event.kind)];
        if !event.session_id.is_empty() {
            attributes.push(attribute("praxo.session.id", &event.session_id));
        }
        if let Some(run_id) = &event.run_id {
            if !run_id.is_empty() {
                attributes.push(attribute("praxo.run.id", run_id));
            }
        }
        if let Some(at) = &event.at {
            attributes.push(attribute("praxo.event.at", at));
        }
        if let Some(data) = &event.data {
            for name in &self.allowed_data_keys {
                if let Some(value) = data.get(name) {
                    attributes.push(attribute(
                        &format!("praxo.event.data.{name}"),
                        &text(value),
                    ));
                }
            }
        }

        let span = json!({
            "traceId": trace_id,
            "spanId": span_id,
            "name": format!("praxo.{}", event.kind),
            "kind": 1,
            "startTimeUnixNano": nanos.to_string(),
            "endTimeUnixNano": nanos.to_string(),
            "attributes": attributes,
        });
        let payload = json!({
            "resourceSpans": [{
                "resource": {
                    "attributes": [attribute("service.name", &self.service_name)]
                },
                "scopeSpans": [{
                    "scope": {"name": "praxo-core"},
                    "spans": [span]
                }]
            }]
        });
        let body = serde_json::to_string(&payload)
            .map_err(|error| PraxoError::new("OTEL_JSON", error.to_string()))?;
        let request = HttpRequest {
            method: "POST".to_string(),
            url: self.endpoint.clone(),
            headers: vec![("content-type".to_string(), "application/json".to_string())],
            body,
        };
        let response = self.transport.send(&request)?;
        if !(200..300).contains(&response.status) {
            let bounded: String = response.body.chars().take(512).collect();
            return Err(PraxoError::new(
                "OTEL_HTTP",
                format!("otel: HTTP {}: {}", response.status, bounded.trim()),
            ));
        }
        Ok(())
    }
}

impl crate::event::Sink for Sink {
    fn emit(&self, event: &Event) -> Result<()> {
        Sink::emit(self, event)
    }
}

fn attribute(key: &str, value: &str) -> Value {
    json!({"key": key, "value": {"stringValue": value}})
}

fn text(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

fn fnv1a(text: &str, seed: u64) -> u64 {
    let mut value = seed;
    for byte in text.as_bytes() {
        value ^= u64::from(*byte);
        value = value.wrapping_mul(0x100000001b3);
    }
    value
}
