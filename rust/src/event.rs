use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::errors::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(rename = "sessionId")]
    pub session_id: String,
    #[serde(default, rename = "runId", skip_serializing_if = "Option::is_none")]
    pub run_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<Map<String, Value>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub at: Option<String>,
}

impl Event {
    pub fn new(kind: impl Into<String>, session_id: impl Into<String>) -> Self {
        Self {
            kind: kind.into(),
            session_id: session_id.into(),
            run_id: None,
            data: None,
            at: Some(now_iso()),
        }
    }

    pub fn run(mut self, run_id: impl Into<String>) -> Self {
        self.run_id = Some(run_id.into());
        self
    }

    pub fn data(mut self, data: Map<String, Value>) -> Self {
        self.data = Some(data);
        self
    }
}

pub trait Sink: Send + Sync {
    fn emit(&self, event: &Event) -> Result<()>;
}

pub struct MultiSink {
    sinks: Vec<std::sync::Arc<dyn Sink>>,
}

impl MultiSink {
    pub fn new(sinks: Vec<std::sync::Arc<dyn Sink>>) -> Self {
        Self { sinks }
    }
}

impl Sink for MultiSink {
    fn emit(&self, event: &Event) -> Result<()> {
        for sink in &self.sinks {
            sink.emit(event)?;
        }
        Ok(())
    }
}

pub struct FilterSink {
    sink: std::sync::Arc<dyn Sink>,
    predicate: Box<dyn Fn(&Event) -> bool + Send + Sync>,
}

impl FilterSink {
    pub fn new(
        sink: std::sync::Arc<dyn Sink>,
        predicate: impl Fn(&Event) -> bool + Send + Sync + 'static,
    ) -> Self {
        Self {
            sink,
            predicate: Box::new(predicate),
        }
    }
}

impl Sink for FilterSink {
    fn emit(&self, event: &Event) -> Result<()> {
        if (self.predicate)(event) {
            self.sink.emit(event)?;
        }
        Ok(())
    }
}

pub fn now_iso() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}.{:09}Z", now.as_secs(), now.subsec_nanos())
}
