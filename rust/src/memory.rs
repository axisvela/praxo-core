use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::errors::Result;

pub const FRAME_EVENT: &str = "event";
pub const FRAME_DECISION: &str = "decision";
pub const FRAME_EXPERIENCE: &str = "experience";
pub const FRAME_PROCEDURE: &str = "procedure";
pub const FRAME_WORKSPACE_STATE: &str = "workspace_state";
pub const FRAME_CONSTRAINT: &str = "constraint";
pub const FRAME_INTENTION: &str = "intention";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MemoryRecord {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub frame: String,
    #[serde(default)]
    pub content: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Map<String, Value>>,
    #[serde(default, rename = "createdAt", skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}

pub trait Store: Send + Sync {
    fn put(&self, session_id: &str, record: MemoryRecord) -> Result<()>;
    fn search(&self, session_id: &str, query: &str, limit: usize) -> Result<Vec<MemoryRecord>>;
}

#[derive(Default)]
pub struct MemoryStore {
    records: std::sync::Mutex<HashMap<String, Vec<MemoryRecord>>>,
    sequence: AtomicU64,
}

impl MemoryStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl Store for MemoryStore {
    fn put(&self, session_id: &str, mut record: MemoryRecord) -> Result<()> {
        if record.id.is_empty() {
            record.id = format!(
                "mem-{}-{}",
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_nanos(),
                self.sequence.fetch_add(1, Ordering::Relaxed)
            );
        }
        if record.created_at.is_none() {
            record.created_at = Some(crate::event::now_iso());
        }
        self.records
            .lock()
            .expect("memory store poisoned")
            .entry(session_id.to_string())
            .or_default()
            .push(record);
        Ok(())
    }

    fn search(&self, session_id: &str, query: &str, limit: usize) -> Result<Vec<MemoryRecord>> {
        let needle = query.trim().to_lowercase();
        let records = self.records.lock().expect("memory store poisoned");
        let mut out: Vec<MemoryRecord> = records
            .get(session_id)
            .map(|items| {
                items
                    .iter()
                    .filter(|item| needle.is_empty() || item.content.to_lowercase().contains(&needle))
                    .cloned()
                    .collect()
            })
            .unwrap_or_default();
        out.sort_by(|left, right| {
            right
                .created_at
                .as_deref()
                .unwrap_or("")
                .cmp(left.created_at.as_deref().unwrap_or(""))
        });
        if limit > 0 && out.len() > limit {
            out.truncate(limit);
        }
        Ok(out)
    }
}
