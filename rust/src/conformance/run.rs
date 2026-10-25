use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use serde_json::{json, Value};

use crate::checkpoint::Allowlist;
use crate::context::{estimate_tokens, ContextBudget};
use crate::event::{Event, FilterSink, MultiSink, Sink};
use crate::jsonschema::validate;
use crate::memory::{MemoryRecord, MemoryStore, Store};
use crate::model::Message;
use crate::plugin::parse_manifest;
use crate::policy::{PathChecker, PathGrant};
use crate::stream::STREAM_KINDS;
use crate::toolcall::{parse, strip_markup};

use super::{agent_loop::run_agent_loop, middleware::run_middleware};

pub fn run_all() -> Vec<String> {
    let root = repo_root();
    let version = fs::read_to_string(root.join("spec").join("SPEC_VERSION"))
        .expect("read SPEC_VERSION")
        .trim()
        .to_string();
    let mut failures = Vec::new();
    let mut seen = HashMap::new();
    let mut paths: Vec<PathBuf> = fs::read_dir(root.join("spec").join("vectors"))
        .expect("read vectors")
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.extension().map(|ext| ext == "json").unwrap_or(false))
        .collect();
    paths.sort();
    for path in paths {
        let file: Value = serde_json::from_str(
            &fs::read_to_string(&path).expect("read vector file"),
        )
        .expect("parse vector file");
        let group = file["group"].as_str().unwrap_or("");
        let name = path
            .file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or("");
        if file["specVersion"].as_str().unwrap_or("") != version {
            failures.push(format!("{name}: specVersion mismatch"));
        }
        if name != group {
            failures.push(format!("{name}: group mismatch"));
        }
        if let Some(vectors) = file["vectors"].as_array() {
            for vector in vectors {
                let id = vector["id"].as_str().unwrap_or("");
                if let Some(previous) = seen.insert(id.to_string(), group.to_string()) {
                    failures.push(format!("{group}/{id}: duplicate id with {previous}"));
                }
                if let Err(error) = run_vector(group, vector) {
                    failures.push(format!("{group}/{id}: {error}"));
                }
            }
        }
    }
    failures
}

fn run_vector(group: &str, vector: &Value) -> Result<(), String> {
    match group {
        "toolcall" => run_toolcall(vector),
        "jsonschema" => run_jsonschema(vector),
        "plugin" => run_plugin(vector),
        "memory" => run_memory(vector),
        "event" => run_event(vector),
        "stream" => run_stream(vector),
        "checkpoint" => run_checkpoint(vector),
        "policy" => run_policy(vector),
        "context" => run_context(vector),
        "middleware" => run_middleware(vector),
        "agent-loop" => run_agent_loop(vector),
        _ => Err(format!("no runner for group {group}")),
    }
}

fn run_toolcall(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let operation = input["operation"].as_str().unwrap_or("");
    let content = input["content"].as_str().unwrap_or("");
    if operation == "strip" {
        check(
            strip_markup(content) == expect["text"].as_str().unwrap_or(""),
            format!("strip: got {}", strip_markup(content)),
        )?;
        return Ok(());
    }
    let call = parse(content);
    if expect["nil"].as_bool().unwrap_or(false) {
        return check(call.is_none(), "expected nil".to_string());
    }
    let call = call.ok_or_else(|| "expected a tool call".to_string())?;
    check(
        call.name == expect["name"].as_str().unwrap_or(""),
        format!("name: got {}", call.name),
    )?;
    let expected = if expect["input"].is_null() {
        json!({})
    } else {
        expect["input"].clone()
    };
    check(
        Value::Object(call.input) == expected,
        "input mismatch".to_string(),
    )
}

fn run_jsonschema(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let errors = validate(&input["schema"], &input["data"]);
    let mut got: Vec<String> = errors.iter().map(|error| error.path.clone()).collect();
    got.sort();
    let mut want: Vec<String> = expect["errorPaths"]
        .as_array()
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default();
    want.sort();
    check(
        errors.is_empty() == expect["valid"].as_bool().unwrap_or(false),
        "valid mismatch".to_string(),
    )?;
    check(got == want, format!("errorPaths: got {got:?}"))
}

fn run_plugin(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let raw = if let Some(raw) = input["raw"].as_str() {
        raw.to_string()
    } else {
        serde_json::to_string(&input["manifest"]).unwrap_or_default()
    };
    let manifest = parse_manifest(&raw).ok();
    check(
        manifest.is_some() == expect["valid"].as_bool().unwrap_or(false),
        "valid mismatch".to_string(),
    )?;
    if let Some(manifest) = manifest {
        if let Some(id) = expect["id"].as_str() {
            check(manifest.id == id, format!("id: got {}", manifest.id))?;
        }
        if let Some(kind) = expect["kind"].as_str() {
            check(manifest.kind == kind, format!("kind: got {}", manifest.kind))?;
        }
    }
    Ok(())
}

fn run_memory(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let store = MemoryStore::new();
    if let Some(puts) = input["puts"].as_array() {
        for put in puts {
            let record: MemoryRecord = serde_json::from_value(put["record"].clone())
                .map_err(|error| error.to_string())?;
            store
                .put(put["session"].as_str().unwrap_or(""), record)
                .map_err(|error| error.message)?;
        }
    }
    let records = store
        .search(
            input["session"].as_str().unwrap_or(""),
            input["query"].as_str().unwrap_or(""),
            input["limit"].as_u64().unwrap_or(0) as usize,
        )
        .map_err(|error| error.message)?;
    let ids: Vec<Value> = records
        .iter()
        .map(|record| Value::String(record.id.clone()))
        .collect();
    let contents: Vec<Value> = records
        .iter()
        .map(|record| Value::String(record.content.clone()))
        .collect();
    check(
        normalize(ids) == expect["ids"],
        "ids mismatch".to_string(),
    )?;
    check(
        normalize(contents) == expect["contents"],
        "contents mismatch".to_string(),
    )
}

fn run_event(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let events: Vec<Event> = input["events"]
        .as_array()
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(|kind| Event::new(kind, "s1"))
                .collect()
        })
        .unwrap_or_default();
    if input["sink"].as_str().unwrap_or("filter") == "multi" {
        let count = input["sinkCount"].as_u64().unwrap_or(1).max(1) as usize;
        let sinks: Vec<Arc<RecordingSink>> = (0..count).map(|_| Arc::new(RecordingSink::default())).collect();
        let multi = MultiSink::new(
            sinks
                .iter()
                .map(|sink| sink.clone() as Arc<dyn Sink>)
                .collect(),
        );
        for event in &events {
            multi.emit(event).map_err(|error| error.message)?;
        }
        let got: Vec<Value> = sinks
            .iter()
            .map(|sink| normalize(sink.types()))
            .collect();
        return check(
            Value::Array(got) == expect["perSink"],
            "perSink mismatch".to_string(),
        );
    }
    let rec = Arc::new(RecordingSink::default());
    let allowed: Option<HashSet<String>> = input["predicateTypes"].as_array().map(|items| {
        items
            .iter()
            .filter_map(Value::as_str)
            .map(str::to_string)
            .collect()
    });
    let sink = FilterSink::new(rec.clone() as Arc<dyn Sink>, move |event| {
        allowed
            .as_ref()
            .map(|allowed| allowed.contains(&event.kind))
            .unwrap_or(true)
    });
    for event in &events {
        sink.emit(event).map_err(|error| error.message)?;
    }
    check(
        normalize(rec.types()) == expect["delivered"],
        "delivered mismatch".to_string(),
    )
}

fn run_stream(vector: &Value) -> Result<(), String> {
    let kinds: Vec<Value> = STREAM_KINDS
        .iter()
        .map(|kind| Value::String(kind.to_string()))
        .collect();
    check(
        Value::Array(kinds) == vector["expect"]["kinds"],
        "kinds mismatch".to_string(),
    )
}

fn run_checkpoint(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let allow = Allowlist::new();
    if let Some(registered) = input["registered"].as_array() {
        for item in registered {
            allow
                .register(item.as_str().unwrap_or(""), || json!({}))
                .map_err(|error| error.message)?;
        }
    }
    let operation = input["operation"].as_str().unwrap_or("roundtrip");
    if operation == "roundtrip" {
        let data = allow
            .marshal(input["type"].as_str().unwrap_or(""), input["value"].clone())
            .map_err(|error| error.message)?;
        let got = allow.unmarshal(&data).map_err(|error| error.message)?;
        return check(got == expect["value"], "value mismatch".to_string());
    }
    let result = if operation == "marshal" {
        allow
            .marshal(input["type"].as_str().unwrap_or(""), input["value"].clone())
            .map(|_| ())
            .map_err(|error| error.code)
    } else if operation == "unmarshal" {
        allow
            .unmarshal(
                &json!({"type": input["type"], "data": input["value"]}).to_string(),
            )
            .map(|_| ())
            .map_err(|error| error.code)
    } else {
        Err("CHECKPOINT_ERROR")
    };
    match result {
        Err(code) => check(
            Some(code) == expect["errorCode"].as_str(),
            format!("errorCode: got {code}"),
        ),
        Ok(()) => check(expect["errorCode"].is_null(), "expected an error".to_string()),
    }
}

fn run_policy(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let base = std::env::temp_dir().join(format!(
        "praxo-policy-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    ));
    fs::create_dir_all(&base).map_err(|error| error.to_string())?;
    let result = (|| -> Result<(), String> {
        if let Some(dirs) = input["makeDirs"].as_array() {
            for dir in dirs {
                fs::create_dir_all(base.join(dir.as_str().unwrap_or("")))
                    .map_err(|error| error.to_string())?;
            }
        }
        let mut grants = Vec::new();
        if let Some(items) = input["grants"].as_array() {
            for item in items {
                let root = base.join(item["root"].as_str().unwrap_or(""));
                fs::create_dir_all(&root).map_err(|error| error.to_string())?;
                grants.push(PathGrant {
                    root: root.to_string_lossy().to_string(),
                    access: item["access"].as_str().unwrap_or("read").to_string(),
                });
            }
        }
        let checker = PathChecker::new(grants).map_err(|error| error.message)?;
        let target = base.join(input["target"].as_str().unwrap_or(""));
        let need = input["need"].as_str().unwrap_or("read");
        if expect["error"].as_bool().unwrap_or(false) {
            match checker.check(&target.to_string_lossy(), need) {
                Err(error) if error.code == "POLICY_ERROR" => return Ok(()),
                Err(error) => return Err(error.message),
                Ok(_) => return Err("expected a policy error".to_string()),
            }
        }
        let allowed = checker
            .check(&target.to_string_lossy(), need)
            .map_err(|error| error.message)?
            .allowed;
        check(
            allowed == expect["allowed"].as_bool().unwrap_or(false),
            format!("allowed: got {allowed}"),
        )
    })();
    let _ = fs::remove_dir_all(&base);
    result
}

fn run_context(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let messages: Vec<Message> = input["messages"]
        .as_array()
        .map(|items| {
            items
                .iter()
                .map(|item| serde_json::from_value(item.clone()).expect("message"))
                .collect()
        })
        .unwrap_or_default();
    if input["operation"].as_str().unwrap_or("") == "estimate" {
        let got = estimate_tokens(&messages) as u64;
        return check(
            got == expect["tokens"].as_u64().unwrap_or(0),
            format!("tokens: got {got}"),
        );
    }
    let budget = ContextBudget::new(
        input["budget"]["maxTokens"].as_u64().unwrap_or(0) as usize,
        input["budget"]["keepRecent"].as_u64().unwrap_or(0) as usize,
    );
    let (out, ok) = budget.compact(&messages);
    check(
        ok == expect["ok"].as_bool().unwrap_or(false),
        format!("ok: got {ok}"),
    )?;
    if !ok {
        return Ok(());
    }
    let got = estimate_tokens(&out) as u64;
    check(
        got == expect["tokens"].as_u64().unwrap_or(0),
        format!("tokens: got {got}"),
    )?;
    let wire = serde_json::to_value(&out).map_err(|error| error.to_string())?;
    check(wire == expect["messages"], "messages mismatch".to_string())
}

#[derive(Default)]
struct RecordingSink {
    types: Mutex<Vec<String>>,
}

impl RecordingSink {
    fn types(&self) -> Vec<Value> {
        self.types
            .lock()
            .expect("recording sink")
            .iter()
            .map(|kind| Value::String(kind.clone()))
            .collect()
    }
}

impl Sink for RecordingSink {
    fn emit(&self, event: &Event) -> crate::errors::Result<()> {
        self.types
            .lock()
            .expect("recording sink")
            .push(event.kind.clone());
        Ok(())
    }
}

fn repo_root() -> PathBuf {
    let mut current = std::env::current_dir().expect("current dir");
    loop {
        if current.join("spec").join("SPEC_VERSION").exists() {
            return current;
        }
        current = current.parent().expect("repository root").to_path_buf();
    }
}

fn normalize(values: Vec<Value>) -> Value {
    if values.is_empty() {
        Value::Null
    } else {
        Value::Array(values)
    }
}

fn check(condition: bool, detail: String) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(detail)
    }
}
