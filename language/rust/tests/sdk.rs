use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use praxo_core::agent::{Agent, AgentOptions, RunResult, Session};
use praxo_core::checkpoint::Allowlist;
use praxo_core::context::{estimate_tokens, ContextBudget};
use praxo_core::event::{Event, Sink};
use praxo_core::jsonschema::Schema;
use praxo_core::middleware::{
    CallLimitMiddleware, Middleware, MiddlewareToolCall, ModelCall, PiiMiddleware, PiiRedactor,
    RunState, StructuredOutput,
};
use praxo_core::model::{Message, Model, Request, Response, ToolCall, Usage};
use praxo_core::plugin::parse_manifest;
use praxo_core::policy::{Action, Decision, Hook, PathChecker, PathGrant};
use praxo_core::tool::{gateway_tools, FuncTool, Gateway, GatewayInfo, Registry};
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
    assert!(out.iter().any(|message| message
        .content
        .as_deref()
        .unwrap_or("")
        .contains("context compacted")));
}

#[test]
fn context_budget_fails_closed() {
    let budget = ContextBudget::new(3, 0);
    let messages = vec![Message::text("system", "x".repeat(1000))];
    let (out, ok) = budget.compact(&messages);
    assert!(!ok);
    assert!(out.is_empty());
}

#[test]
fn call_limit_model_and_tool_fail_closed() {
    let middleware = CallLimitMiddleware::new(1, 1);
    middleware
        .before_run(&RunState {
            run_id: "r1".into(),
            prompt: "go".into(),
        })
        .expect("run");
    let mut model = ModelCall {
        run_id: "r1".into(),
        session_id: "s1".into(),
        request: Request::of(vec![]),
        skip: false,
        response: None,
    };
    middleware.before_model(&mut model).expect("first model");
    assert!(middleware.before_model(&mut model).is_err());
    let mut tool = MiddlewareToolCall {
        run_id: "r1".into(),
        session_id: "s1".into(),
        call: ToolCall {
            id: "c1".into(),
            name: "echo".into(),
            arguments: Map::new(),
        },
        skip: false,
        result: None,
        error: None,
    };
    middleware.before_tool(&mut tool).expect("first tool");
    assert!(middleware.before_tool(&mut tool).is_err());
}

#[test]
fn call_limit_state_is_isolated_by_run() {
    let middleware = CallLimitMiddleware::new(1, 0);
    middleware
        .before_run(&RunState {
            run_id: "a".into(),
            prompt: "go".into(),
        })
        .expect("run a");
    middleware
        .before_run(&RunState {
            run_id: "b".into(),
            prompt: "go".into(),
        })
        .expect("run b");
    let mut first = ModelCall {
        run_id: "a".into(),
        session_id: "s1".into(),
        request: Request::of(vec![]),
        skip: false,
        response: None,
    };
    let mut second = ModelCall {
        run_id: "b".into(),
        session_id: "s1".into(),
        request: Request::of(vec![]),
        skip: false,
        response: None,
    };
    middleware.before_model(&mut first).expect("first run");
    middleware.before_model(&mut second).expect("second run");
}

#[test]
fn pii_redacts_email() {
    let redactor = PiiRedactor::defaults();
    assert_eq!(redactor.redact("a@b.com"), "[REDACTED:email]");
}

#[test]
fn pii_redacts_tool_call_history() {
    let mut original = Map::new();
    original.insert("email".into(), json!("a@b.com"));
    original.insert("nested".into(), json!({"ssn": "123-45-6789"}));
    let middleware = PiiMiddleware::new(PiiRedactor::defaults());
    let mut call = ModelCall {
        run_id: "r1".into(),
        session_id: "s1".into(),
        request: Request::of(vec![Message::assistant(
            "",
            vec![ToolCall {
                id: "call-1".into(),
                name: "lookup".into(),
                arguments: original.clone(),
            }],
        )]),
        skip: false,
        response: None,
    };
    middleware.before_model(&mut call).unwrap();
    let redacted = &call.request.messages[0].tool_calls[0].arguments;
    assert_eq!(redacted["email"], json!("[REDACTED:email]"));
    assert_eq!(redacted["nested"]["ssn"], json!("[REDACTED:ssn]"));
    assert_eq!(original["email"], json!("a@b.com"));
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
    allow
        .register("spec.payload", || json!({}))
        .expect("register");
    let data = allow
        .marshal("spec.payload", json!({"value": "x"}))
        .expect("marshal");
    assert_eq!(
        allow.unmarshal(&data).expect("unmarshal"),
        json!({"value": "x"})
    );
}

struct RecordingGateway {
    calls: Mutex<Vec<(String, String)>>,
}

impl Gateway for RecordingGateway {
    fn execute(
        &self,
        name: &str,
        input: &Map<String, Value>,
        token: &str,
    ) -> praxo_core::errors::Result<Value> {
        self.calls
            .lock()
            .expect("gateway")
            .push((name.to_string(), token.to_string()));
        Ok(json!({"name": name, "input": input}))
    }

    fn list_tools(&self) -> Vec<GatewayInfo> {
        vec![
            GatewayInfo {
                name: "z.tool".to_string(),
                description: "last".to_string(),
                risk: "low".to_string(),
            },
            GatewayInfo {
                name: "a.tool".to_string(),
                description: "first".to_string(),
                risk: "high".to_string(),
            },
        ]
    }
}

#[test]
fn gateway_tools_are_sorted_and_dispatch() {
    let gateway = Arc::new(RecordingGateway {
        calls: Mutex::new(Vec::new()),
    });
    let tools = gateway_tools(gateway.clone());
    assert_eq!(tools.len(), 2);
    assert_eq!(tools[0].name(), "a.tool");
    assert_eq!(tools[1].name(), "z.tool");
    let value = tools[0]
        .invoke(&Map::from_iter([("x".to_string(), json!(1))]))
        .expect("invoke");
    assert_eq!(value["name"], json!("a.tool"));
    assert_eq!(
        gateway.calls.lock().expect("calls").as_slice(),
        &[("a.tool".to_string(), String::new())]
    );
}

#[test]
fn schema_parses_and_validates() {
    let schema = Schema::from_json(
        r#"{"type":"object","required":["path"],"properties":{"path":{"type":"string","minLength":1}}}"#,
    )
    .expect("schema");
    assert!(schema.validate(&json!({"path": "a"})).is_empty());
    assert_eq!(
        schema.validate(&json!({"path": ""}))[0].message,
        "min length 1, got 0"
    );
    assert!(Schema::from_json("[]").is_err());
    assert!(Schema::from_json("not json").is_err());
}

#[test]
fn schema_counts_unicode_and_rejects_fractional_integers() {
    let integer = Schema::from_json(r#"{"type":"integer"}"#).expect("integer");
    assert!(integer.validate(&json!(2)).is_empty());
    assert_eq!(integer.validate(&json!(2.5)).len(), 1);
    let text = Schema::from_json(r#"{"type":"string","minLength":2,"maxLength":2}"#)
        .expect("string");
    assert!(text.validate(&json!("你好")).is_empty());
    assert_eq!(text.validate(&json!("你")).len(), 1);
}


struct RecordingPolicy {
    actions: Mutex<Vec<Action>>,
    deny_tool: bool,
}

impl RecordingPolicy {
    fn new(deny_tool: bool) -> Self {
        Self {
            actions: Mutex::new(Vec::new()),
            deny_tool,
        }
    }

    fn actions(&self) -> Vec<Action> {
        self.actions.lock().expect("actions").clone()
    }
}

impl Hook for RecordingPolicy {
    fn authorize(&self, action: &Action) -> praxo_core::errors::Result<Decision> {
        self.actions.lock().expect("actions").push(action.clone());
        if self.deny_tool && action.kind == "tool.invoke" {
            return Ok(Decision::deny("blocked"));
        }
        Ok(Decision::allow("ok"))
    }
}

struct MutatingMiddleware {
    name: Option<String>,
    arguments: Option<Map<String, Value>>,
    before_tool_calls: AtomicUsize,
}

impl MutatingMiddleware {
    fn new(name: Option<&str>, arguments: Option<Map<String, Value>>) -> Self {
        Self {
            name: name.map(str::to_string),
            arguments,
            before_tool_calls: AtomicUsize::new(0),
        }
    }
}

impl Middleware for MutatingMiddleware {
    fn before_tool(&self, call: &mut MiddlewareToolCall) -> praxo_core::errors::Result<()> {
        self.before_tool_calls.fetch_add(1, Ordering::SeqCst);
        if let Some(name) = &self.name {
            call.call.name = name.clone();
        }
        if let Some(arguments) = &self.arguments {
            call.call.arguments = arguments.clone();
        }
        Ok(())
    }
}

fn tool_call_response(name: &str, arguments: Map<String, Value>) -> Response {
    Response {
        message: Message::assistant(
            "",
            vec![ToolCall {
                id: "c1".to_string(),
                name: name.to_string(),
                arguments,
            }],
        ),
        usage: Usage::default(),
        finish_reason: None,
    }
}

fn done_response() -> Response {
    Response {
        message: Message::assistant("done", Vec::new()),
        usage: Usage::default(),
        finish_reason: None,
    }
}

fn echo_registry(invoked: Arc<Mutex<Vec<Map<String, Value>>>>) -> Registry {
    let mut registry = Registry::new();
    let calls = invoked.clone();
    registry.register(Arc::new(FuncTool::new("echo", "Echo", move |args| {
        calls.lock().expect("calls").push(args.clone());
        Ok(Value::Object(args.clone()))
    })));
    registry
}

#[test]
fn final_arguments_are_reauthorized_and_executed() {
    let invoked = Arc::new(Mutex::new(Vec::new()));
    let model = Arc::new(ScriptedModel::new(vec![
        tool_call_response("echo", Map::from_iter([("text".to_string(), json!("hi"))])),
        done_response(),
    ]));
    let policy = Arc::new(RecordingPolicy::new(false));
    let middleware = MutatingMiddleware::new(
        None,
        Some(Map::from_iter([("text".to_string(), json!("mutated"))])),
    );
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(echo_registry(invoked.clone())));
    options.policy = Some(policy.clone());
    options.middleware.push(Box::new(middleware));
    let result = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect("run");
    assert_eq!(result.output, "done");
    assert_eq!(
        invoked.lock().expect("calls").as_slice(),
        &[Map::from_iter([("text".to_string(), json!("mutated"))])]
    );
    let tool_actions: Vec<Action> = policy
        .actions()
        .into_iter()
        .filter(|action| action.kind == "tool.invoke")
        .collect();
    assert_eq!(tool_actions.len(), 2);
    assert_eq!(tool_actions[0].arguments.as_ref().unwrap()["text"], json!("hi"));
    assert_eq!(
        tool_actions[1].arguments.as_ref().unwrap()["text"],
        json!("mutated")
    );
}

#[test]
fn final_name_uses_final_tool_and_checks_allowlist() {
    let echo_invoked = Arc::new(Mutex::new(Vec::new()));
    let other_invoked = Arc::new(Mutex::new(Vec::new()));
    let mut registry = echo_registry(echo_invoked.clone());
    let other_calls = other_invoked.clone();
    registry.register(Arc::new(FuncTool::new("other", "Other", move |args| {
        other_calls.lock().expect("calls").push(args.clone());
        Ok(Value::Object(args.clone()))
    })));
    let model = Arc::new(ScriptedModel::new(vec![
        tool_call_response("echo", Map::from_iter([("text".to_string(), json!("hi"))])),
        done_response(),
    ]));
    let policy = Arc::new(RecordingPolicy::new(false));
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(registry));
    options.policy = Some(policy.clone());
    options
        .middleware
        .push(Box::new(MutatingMiddleware::new(Some("other"), None)));
    Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect("run");
    assert!(echo_invoked.lock().expect("echo").is_empty());
    assert_eq!(other_invoked.lock().expect("other").len(), 1);
    let names: Vec<String> = policy
        .actions()
        .into_iter()
        .filter(|action| action.kind == "tool.invoke")
        .map(|action| action.tool_name.unwrap_or_default())
        .collect();
    assert_eq!(names, vec!["echo".to_string(), "other".to_string()]);

    let denied_model = Arc::new(ScriptedModel::new(vec![
        tool_call_response("echo", Map::new()),
        done_response(),
    ]));
    let mut denied = AgentOptions::new(denied_model);
    denied.tools = Some(Arc::new(echo_registry(Arc::new(Mutex::new(Vec::new())))));
    denied.allowed_tools = vec!["echo".to_string()];
    denied
        .middleware
        .push(Box::new(MutatingMiddleware::new(Some("other"), None)));
    let error = Agent::new(denied)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect_err("denied");
    assert_eq!(error.code, "AGENT_TOOL_NOT_ALLOWED");
}

#[test]
fn unchanged_tool_is_authorized_once() {
    let model = Arc::new(ScriptedModel::new(vec![
        tool_call_response("echo", Map::from_iter([("text".to_string(), json!("hi"))])),
        done_response(),
    ]));
    let policy = Arc::new(RecordingPolicy::new(false));
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(echo_registry(Arc::new(Mutex::new(Vec::new())))));
    options.policy = Some(policy.clone());
    options
        .middleware
        .push(Box::new(MutatingMiddleware::new(None, None)));
    Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect("run");
    let count = policy
        .actions()
        .into_iter()
        .filter(|action| action.kind == "tool.invoke")
        .count();
    assert_eq!(count, 1);
}

#[test]
fn initial_denial_precedes_middleware_and_effect() {
    let invoked = Arc::new(Mutex::new(Vec::new()));
    let model = Arc::new(ScriptedModel::new(vec![
        tool_call_response("echo", Map::new()),
        done_response(),
    ]));
    let policy = Arc::new(RecordingPolicy::new(true));
    let middleware = Arc::new(MutatingMiddleware::new(Some("other"), None));
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(echo_registry(invoked.clone())));
    options.policy = Some(policy);
    options.middleware.push(Box::new(SharedMiddleware(middleware.clone())));
    let error = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect_err("denied");
    assert_eq!(error.code, "AGENT_POLICY_DENIED");
    assert_eq!(middleware.before_tool_calls.load(Ordering::SeqCst), 0);
    assert!(invoked.lock().expect("calls").is_empty());
}

struct SharedMiddleware(Arc<MutatingMiddleware>);

impl Middleware for SharedMiddleware {
    fn before_tool(&self, call: &mut MiddlewareToolCall) -> praxo_core::errors::Result<()> {
        self.0.before_tool(call)
    }
}


type BeforeHook = Box<dyn Fn(&RunState) -> praxo_core::errors::Result<()> + Send + Sync>;
type AfterHook = Box<
    dyn Fn(
            Option<&mut RunResult>,
            Option<&praxo_core::errors::PraxoError>,
        ) -> praxo_core::errors::Result<()>
        + Send
        + Sync,
>;

struct LifecycleMiddleware {
    before: Option<BeforeHook>,
    after: Option<AfterHook>,
}

impl LifecycleMiddleware {
    fn new(before: Option<BeforeHook>, after: Option<AfterHook>) -> Self {
        Self { before, after }
    }
}

impl Middleware for LifecycleMiddleware {
    fn before_run(&self, state: &RunState) -> praxo_core::errors::Result<()> {
        if let Some(hook) = &self.before {
            hook(state)?;
        }
        Ok(())
    }

    fn after_run(
        &self,
        result: Option<&mut RunResult>,
        error: Option<&praxo_core::errors::PraxoError>,
    ) -> praxo_core::errors::Result<()> {
        if let Some(hook) = &self.after {
            hook(result, error)?;
        }
        Ok(())
    }
}

#[test]
fn startup_failure_cleans_entered_without_events() {
    let calls = Arc::new(Mutex::new(Vec::new()));
    let sink = Arc::new(RecordingSink {
        types: Mutex::new(Vec::new()),
    });
    let first_calls = calls.clone();
    let first = LifecycleMiddleware::new(
        Some(Box::new(move |_| {
            first_calls.lock().expect("calls").push("first.before".to_string());
            Ok(())
        })),
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("first.after".to_string());
                Ok(())
            }
        })),
    );
    let second_calls = calls.clone();
    let second = LifecycleMiddleware::new(
        Some(Box::new(move |_| {
            second_calls
                .lock()
                .expect("calls")
                .push("second.before".to_string());
            Err(praxo_core::errors::PraxoError::new(
                "STARTUP_FAILED",
                "startup failed",
            ))
        })),
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("second.after".to_string());
                Ok(())
            }
        })),
    );
    let third_calls = calls.clone();
    let third = LifecycleMiddleware::new(
        Some(Box::new(move |_| {
            third_calls.lock().expect("calls").push("third.before".to_string());
            Ok(())
        })),
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("third.after".to_string());
                Ok(())
            }
        })),
    );
    let model = Arc::new(ScriptedModel::new(vec![done_response()]));
    let mut options = AgentOptions::new(model);
    options.events = Some(sink.clone());
    options.middleware.push(Box::new(first));
    options.middleware.push(Box::new(second));
    options.middleware.push(Box::new(third));
    let error = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect_err("startup failure");
    assert_eq!(error.code, "STARTUP_FAILED");
    assert_eq!(
        calls.lock().expect("calls").as_slice(),
        &[
            "first.before".to_string(),
            "second.before".to_string(),
            "first.after".to_string(),
            "second.after".to_string(),
        ]
    );
    assert!(sink.types.lock().expect("sink").is_empty());
}

#[test]
fn after_run_continues_and_preserves_run_error() {
    let calls = Arc::new(Mutex::new(Vec::new()));
    let first = LifecycleMiddleware::new(
        None,
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("first.after".to_string());
                Err(praxo_core::errors::PraxoError::new(
                    "CLEANUP_FAILED",
                    "cleanup failed",
                ))
            }
        })),
    );
    let second = LifecycleMiddleware::new(
        None,
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("second.after".to_string());
                Ok(())
            }
        })),
    );
    let model = Arc::new(ScriptedModel::new(vec![]));
    let mut options = AgentOptions::new(model);
    options.middleware.push(Box::new(first));
    options.middleware.push(Box::new(second));
    let error = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect_err("run failure");
    assert_eq!(error.code, "SCRIPT");
    assert_eq!(
        calls.lock().expect("calls").as_slice(),
        &["first.after".to_string(), "second.after".to_string()]
    );
}

#[test]
fn cleanup_error_after_success_fails_closed() {
    let calls = Arc::new(Mutex::new(Vec::new()));
    let sink = Arc::new(RecordingSink {
        types: Mutex::new(Vec::new()),
    });
    let first = LifecycleMiddleware::new(
        None,
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("first.after".to_string());
                Err(praxo_core::errors::PraxoError::new(
                    "CLEANUP_FAILED",
                    "cleanup failed",
                ))
            }
        })),
    );
    let second = LifecycleMiddleware::new(
        None,
        Some(Box::new({
            let calls = calls.clone();
            move |_, _| {
                calls.lock().expect("calls").push("second.after".to_string());
                Ok(())
            }
        })),
    );
    let model = Arc::new(ScriptedModel::new(vec![done_response()]));
    let mut options = AgentOptions::new(model);
    options.events = Some(sink.clone());
    options.middleware.push(Box::new(first));
    options.middleware.push(Box::new(second));
    let error = Agent::new(options)
        .expect("agent")
        .run(&Session::new("s1"), "go")
        .expect_err("cleanup failure");
    assert_eq!(error.code, "CLEANUP_FAILED");
    assert_eq!(
        calls.lock().expect("calls").as_slice(),
        &["first.after".to_string(), "second.after".to_string()]
    );
    assert_eq!(
        sink.types.lock().expect("sink").as_slice(),
        &["run.started".to_string(), "run.failed".to_string()]
    );
}
