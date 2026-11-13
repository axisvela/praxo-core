use std::collections::HashMap;

use praxo_core::checkpoint::Allowlist;
use serde_json::{json, Value};

struct CheckpointRecord {
    id: String,
    session_id: String,
    version: u64,
    payload: String,
}

#[derive(Default)]
struct MemoryStore {
    records: HashMap<String, CheckpointRecord>,
}

impl MemoryStore {
    fn save(&mut self, record: CheckpointRecord) {
        self.records.insert(record.session_id.clone(), record);
    }

    fn load(&self, session_id: &str) -> Option<&CheckpointRecord> {
        self.records.get(session_id)
    }
}

fn default_allowlist() -> Allowlist {
    let allowlist = Allowlist::new();
    allowlist
        .register("order", || json!({"session_id": "", "items": []}))
        .expect("register type");
    allowlist
}

fn save_checkpoint(
    store: &mut MemoryStore,
    allowlist: &Allowlist,
    session_id: &str,
    version: u64,
    items: &[&str],
) {
    let payload = allowlist
        .marshal("order", json!({"session_id": session_id, "items": items}))
        .expect("marshal payload");
    store.save(CheckpointRecord {
        id: format!("cp-{version}"),
        session_id: session_id.to_string(),
        version,
        payload,
    });
}

fn main() {
    let allowlist = default_allowlist();
    let mut store = MemoryStore::default();
    save_checkpoint(&mut store, &allowlist, "session-1", 1, &["book"]);
    save_checkpoint(&mut store, &allowlist, "session-1", 2, &["book", "pen"]);

    let loaded = store.load("session-1").expect("checkpoint");
    assert_eq!(loaded.id, "cp-2");
    assert_eq!(loaded.version, 2);
    let payload = allowlist.unmarshal(&loaded.payload).expect("unmarshal");
    assert_eq!(
        payload["session_id"],
        Value::String("session-1".to_string())
    );
    assert_eq!(payload["items"], json!(["book", "pen"]));

    let error = allowlist
        .marshal("unknown", json!({"session_id": "session-1"}))
        .expect_err("unregistered type");
    assert_eq!(error.code, "CHECKPOINT_TYPE_NOT_ALLOWED");

    println!("checkpoint test: ok");
}
