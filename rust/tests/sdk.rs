use std::sync::{Arc, Mutex};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::checkpoint::Allowlist;
use praxo_core::context::{estimate_tokens, ContextBudget};
use praxo_core::event::{Event, Sink};
use praxo_core::middleware::{PiiRedactor, StructuredOutput};
use praxo_core::model::{Message, Model, Request, Response, ToolCall, Usage};
use praxo_core::plugin::parse_manifest;
use praxo_core::policy::{PathChecker, PathGrant};
use praxo_core::tool::{FuncTool, Registry};
use serde_json::{json, Map, Value};

struct ScriptedModel {
    responses: Mutex<Vec<Response>>,
}

impl ScriptedModel {
    fn new(responses: Vec<Response>) -> Self {
        Self {
            responses: Mutex::new(responses),
        }
    }
}

impl Model for ScriptedModel {
    fn generate(&self, _request: &Request) -> praxo_core::errors::Result<Response> {
        let mut responses = self.responses.lock().expect("script");
        if responses.is_empty() {
            return Err(praxo_core::errors::PraxoError::new(
                "SCRIPT",
                "script exhausted",
            ));
        }
        Ok(responses.remove(0))
    }
}

struct RecordingSink {
    types: Mutex<Vec<String>>,
}

impl Sink for RecordingSink {
    fn emit(&self, event: &Event) -> praxo_core::errors::Result<()> {
        self.types.lock().expect("sink").push(event.kind.clone());
        Ok(())
    }
}

#[test]
fn agent_runs_tool_then_final() {
    let tool_call = ToolCall {
        id: "c1".to_string(),
        name: "echo".to_string(),
        arguments: Map::from_iter([("text".to_string(), json!("hi"))]),
    };
    let model = Arc::new(ScriptedModel::new(vec![
        Response {
            message: Message::assistant("", vec![tool_call]),
            usage: Usage::default(),
            finish_reason: None,
        },
        Response {
            message: Message::assistant("done", Vec::new()),
            usage: Usage::default(),
            finish_reason: None,
        },
    ]));
    let mut registry = Registry::new();
    registry.register(Arc::new(FuncTool::new("echo", "Echo", |args| {
        Ok(Value::Object(args.clone()))
    })));
    let sink = Arc::new(RecordingSink {
        types: Mutex::new(Vec::new()),
    });
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(registry));
    options.events = Some(sink.clone());
    let result = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect("run");
    assert_eq!(result.output, "done");
    assert_eq!(result.steps, 2);
    assert_eq!(
        *sink.types.lock().expect("sink"),
        vec!["run.started", "tool.call", "run.completed"]
    );
}

#[test]
fn context_budget_compacts() {
    let mut messages = vec![Message::text("system", "sys")];
    for index in 0..10 {
        messages.push(Message::text("user", format!("message {index}")));
    }
    let budget = ContextBudget::new(30, 2);
    let (out, ok) = budget.compact(&messages);
    assert!(ok);
    assert!(estimate_tokens(&out) <= 30);
    assert!(out
        .iter()
        .any(|message| message.content.as_deref().unwrap_or("").contains("context compacted")));
}

#[test]
fn pii_redacts_email() {
    let redactor = PiiRedactor::defaults();
    assert_eq!(redactor.redact("a@b.com"), "[REDACTED:email]");
}

#[test]
fn structured_output_validates_and_repairs() {
    let output = StructuredOutput::new(
        json!({
            "type": "object",
            "properties": {"value": {"type": "integer"}},
            "required": ["value"]
        })
        .as_object()
        .expect("schema")
        .clone(),
    )
    .with_repairs(1)
    .with_repairer(|_, _| Ok("{\"value\":2}".to_string()));
    let mut result = praxo_core::agent::RunResult {
        run_id: "r1".to_string(),
        output: "{\"value\":\"bad\"}".to_string(),
        steps: 0,
        usage: Usage::default(),
    };
    output.apply(&mut result).expect("repair");
    assert_eq!(result.output, "{\"value\":2}");
}

#[test]
fn plugin_rejects_unknown_fields() {
    let manifest = json!({
        "schemaVersion": 1,
        "id": "com.example.echo",
        "version": "1.0.0",
        "kind": "tool.provider.v1",
        "entrypoint": {"type": "process", "command": "echo"},
        "protocol": "jsonrpc-2",
        "capabilities": [],
        "permissions": {},
        "limits": {},
        "health": {},
        "isolation": "process"
    });
    assert!(parse_manifest(&manifest.to_string()).is_ok());
    let mut invalid = manifest;
    invalid["extra"] = json!(true);
    assert!(parse_manifest(&invalid.to_string()).is_err());
}

#[test]
fn path_checker_denies_traversal() {
    let base = std::env::temp_dir().join(format!(
        "praxo-rust-policy-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    ));
    std::fs::create_dir_all(base.join("root")).expect("root");
    let checker = PathChecker::new(vec![PathGrant {
        root: base.join("root").to_string_lossy().to_string(),
        access: "readwrite".to_string(),
    }])
    .expect("checker");
    assert!(checker.allowed(&base.join("root/a.txt").to_string_lossy(), "read"));
    assert!(!checker.allowed(&base.join("outside/a.txt").to_string_lossy(), "read"));
    let _ = std::fs::remove_dir_all(base);
}

#[test]
fn checkpoint_round_trips() {
    let allow = Allowlist::new();
    allow.register("spec.payload", || json!({})).expect("register");
    let data = allow
        .marshal("spec.payload", json!({"value": "x"}))
        .expect("marshal");
    assert_eq!(allow.unmarshal(&data).expect("unmarshal"), json!({"value": "x"}));
}
