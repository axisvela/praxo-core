use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use praxo_core::adapters::harmovela::{self, HttpRequest, HttpResponse, Transport};
use praxo_core::adapters::mcp::{
    McpClient, McpHttpRequest, McpHttpResponse, McpHttpTransport,
};
use praxo_core::adapters::otel;
use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::event::{MultiSink, Sink as EventSink};
use praxo_core::middleware::{Middleware, MiddlewareToolCall};
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};
use serde_json::{json, Map, Value};

type Effects = Arc<Mutex<HashMap<String, usize>>>;
type EventLog = Arc<Mutex<Vec<String>>>;

fn new_effects() -> Effects {
    Arc::new(Mutex::new(HashMap::new()))
}

fn bump(effects: &Effects, target: &str) {
    *effects
        .lock()
        .expect("effects")
        .entry(target.to_string())
        .or_insert(0) += 1;
}

fn effect_count(effects: &Effects, target: &str) -> usize {
    *effects.lock().expect("effects").get(target).unwrap_or(&0)
}

struct RecordTransport {
    effects: Effects,
}

impl McpHttpTransport for RecordTransport {
    fn post(&self, request: McpHttpRequest) -> Result<McpHttpResponse> {
        let message = &request.message;
        let method = message
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let id = message.get("id").cloned().unwrap_or(Value::Null);
        if id.is_null() {
            return Ok(McpHttpResponse {
                status: 202,
                content_type: "application/json".to_string(),
                body: String::new(),
                session_id: None,
            });
        }
        let params = message.get("params").cloned().unwrap_or(Value::Null);
        let result = match method {
            "initialize" => json!({
                "protocolVersion": "2025-03-26",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "chain-mcp", "version": "0.0.1"},
            }),
            "tools/list" => json!({
                "tools": [{
                    "name": "record",
                    "description": "Record a target",
                    "inputSchema": {
                        "type": "object",
                        "properties": {"target": {"type": "string"}},
                        "required": ["target"],
                    },
                }],
            }),
            "tools/call" => record_call(self, &params),
            _ => return Ok(error_response(id, -32601, "method not found")),
        };
        Ok(McpHttpResponse {
            status: 200,
            content_type: "application/json".to_string(),
            body: json!({"jsonrpc": "2.0", "id": id, "result": result}).to_string(),
            session_id: None,
        })
    }
}

fn record_call(transport: &RecordTransport, params: &Value) -> Value {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if name != "record" {
        return json!({
            "content": [{"type": "text", "text": "unknown tool"}],
            "isError": true,
        });
    }
    let target = params
        .get("arguments")
        .and_then(|arguments| arguments.get("target"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    bump(&transport.effects, &target);
    json!({
        "content": [{"type": "text", "text": format!("recorded:{target}")}],
        "isError": false,
    })
}

fn error_response(id: Value, code: i64, message: &str) -> McpHttpResponse {
    McpHttpResponse {
        status: 200,
        content_type: "application/json".to_string(),
        body: json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": {"code": code, "message": message},
        })
        .to_string(),
        session_id: None,
    }
}

fn mcp_record(effects: Effects) -> Result<(McpClient, Arc<dyn Tool>)> {
    let transport = Arc::new(RecordTransport { effects });
    let client = McpClient::connect_http_with_timeout(transport, Duration::from_secs(2))?;
    let mut registry = Registry::new();
    let tools = client.register_tools(&mut registry)?;
    let record = tools.into_iter().next().ok_or_else(|| {
        PraxoError::new("CHAIN_TOOL", "representative chain: missing record tool")
    })?;
    Ok((client, record))
}

struct OtelTransport {
    log: EventLog,
}

impl Transport for OtelTransport {
    fn send(&self, request: &HttpRequest) -> Result<HttpResponse> {
        let payload: Value =
            serde_json::from_str(&request.body).unwrap_or(Value::Null);
        let resources = payload.get("resourceSpans").and_then(Value::as_array);
        for resource in resources.into_iter().flatten() {
            let scopes = resource.get("scopeSpans").and_then(Value::as_array);
            for scope in scopes.into_iter().flatten() {
                let spans = scope.get("spans").and_then(Value::as_array);
                for span in spans.into_iter().flatten() {
                    if let Some(name) = span.get("name").and_then(Value::as_str) {
                        self.log.lock().expect("otel log").push(name.to_string());
                    }
                }
            }
        }
        Ok(HttpResponse {
            status: 200,
            body: String::new(),
        })
    }
}

struct HarmovelaTransport {
    log: EventLog,
}

impl Transport for HarmovelaTransport {
    fn send(&self, request: &HttpRequest) -> Result<HttpResponse> {
        let payload: Value =
            serde_json::from_str(&request.body).unwrap_or(Value::Null);
        if let Some(kind) = payload.get("type").and_then(Value::as_str) {
            self.log
                .lock()
                .expect("harmovela log")
                .push(kind.to_string());
        }
        Ok(HttpResponse {
            status: 202,
            body: String::new(),
        })
    }
}

struct ScriptedModel {
    steps: Mutex<VecDeque<Vec<ToolCall>>>,
    final_output: String,
    calls: Arc<AtomicUsize>,
}

impl ScriptedModel {
    fn new(steps: Vec<Vec<ToolCall>>, final_output: &str, calls: Arc<AtomicUsize>) -> Self {
        Self { steps: Mutex::new(steps.into()), final_output: final_output.to_string(), calls }
    }
}

impl Model for ScriptedModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        let step = self.steps.lock().expect("steps").pop_front();
        let message = match step {
            Some(tool_calls) => Message::assistant("", tool_calls),
            None => Message::assistant(self.final_output.clone(), Vec::new()),
        };
        Ok(Response {
            message,
            ..Response::default()
        })
    }
}

fn tool_call(id: &str, name: &str, arguments: Value) -> ToolCall {
    ToolCall {
        id: id.to_string(),
        name: name.to_string(),
        arguments: arguments.as_object().cloned().unwrap_or_default(),
    }
}

struct ParentPolicy;

impl Hook for ParentPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("parent generation")),
            "tool.invoke" => {
                let name = action.tool_name.as_deref().unwrap_or_default();
                if name == "record" {
                    let blocked = action
                        .arguments
                        .as_ref()
                        .and_then(|arguments| arguments.get("target"))
                        .and_then(Value::as_str)
                        == Some("blocked");
                    if blocked {
                        return Ok(Decision::deny("blocked target"));
                    }
                    return Ok(Decision::allow("parent may record"));
                }
                if name == "delegate" {
                    return Ok(Decision::allow("parent may delegate"));
                }
                Ok(Decision::deny("parent tool is not allowed"))
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

struct ChildOnlyPolicy;

impl Hook for ChildOnlyPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("child generation")),
            "tool.invoke" => {
                if action.tool_name.as_deref() == Some("record") {
                    Ok(Decision::allow("child may only record"))
                } else {
                    Ok(Decision::deny("child may only record"))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

struct ComposedPolicy {
    hooks: Vec<Arc<dyn Hook>>,
}

impl ComposedPolicy {
    fn new(hooks: Vec<Arc<dyn Hook>>) -> Self {
        Self { hooks }
    }
}

impl Hook for ComposedPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        for hook in &self.hooks {
            let decision = hook.authorize(action)?;
            if !decision.allowed {
                return Ok(decision);
            }
        }
        Ok(Decision::allow("delegation policy chain allowed"))
    }
}

struct DelegateTool {
    record: Arc<dyn Tool>,
    child_model: Arc<dyn Model>,
    effects: Effects,
    events: Arc<dyn EventSink>,
}

impl Tool for DelegateTool {
    fn name(&self) -> &str {
        "delegate"
    }

    fn description(&self) -> &str {
        "Run a governed child agent with the narrowed record scope"
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        let mut registry = Registry::new();
        registry.register(self.record.clone());
        let policy = Arc::new(ComposedPolicy::new(vec![
            Arc::new(ParentPolicy),
            Arc::new(ChildOnlyPolicy),
        ]));
        let mut options = AgentOptions::new(self.child_model.clone());
        options.tools = Some(Arc::new(registry));
        options.events = Some(self.events.clone());
        options.allowed_tools = vec!["record".to_string()];
        options.policy = Some(policy);
        options.require_policy = true;
        options.require_tool_scope = true;
        options.max_steps = 3;
        let child = Agent::new(options)?;
        let result = child.run(&Session::new("chain-child"), "record child")?;
        Ok(json!({
            "output": result.output,
            "effects": effect_count(&self.effects, "child"),
        }))
    }
}

struct BlockedEdit;

impl Middleware for BlockedEdit {
    fn before_tool(&self, call: &mut MiddlewareToolCall) -> Result<()> {
        call.call
            .arguments
            .insert("target".to_string(), json!("blocked"));
        Ok(())
    }
}

struct Summary {
    output: String,
    effects: HashMap<String, usize>,
    child_calls: usize,
    otel: Vec<String>,
    harmovela: Vec<String>,
    denied_effect: usize,
    denial_code: String,
}

fn run_chain() -> Result<Summary> {
    let effects = new_effects();
    let (_client, record) = mcp_record(effects.clone())?;

    let otel_log: EventLog = Arc::new(Mutex::new(Vec::new()));
    let harmovela_log: EventLog = Arc::new(Mutex::new(Vec::new()));
    let otel_sink: Arc<dyn EventSink> = Arc::new(otel::Sink::with_transport(
        "http://otel.local/v1/traces",
        Arc::new(OtelTransport {
            log: otel_log.clone(),
        }),
    ));
    let harmovela_sink: Arc<dyn EventSink> = Arc::new(harmovela::Sink::with_transport(
        "http://harmovela.local",
        Arc::new(HarmovelaTransport {
            log: harmovela_log.clone(),
        }),
    ));
    let events: Arc<dyn EventSink> =
        Arc::new(MultiSink::new(vec![otel_sink, harmovela_sink]));

    let child_calls = Arc::new(AtomicUsize::new(0));
    let child_model: Arc<dyn Model> = Arc::new(ScriptedModel::new(
        vec![vec![tool_call(
            "child-record",
            "record",
            json!({"target": "child"}),
        )]],
        "CHILD-DONE",
        child_calls.clone(),
    ));
    let parent_model: Arc<dyn Model> = Arc::new(ScriptedModel::new(
        vec![
            vec![tool_call(
                "parent-record",
                "record",
                json!({"target": "parent"}),
            )],
            vec![tool_call(
                "parent-delegate",
                "delegate",
                json!({"task": "child"}),
            )],
        ],
        "DONE",
        Arc::new(AtomicUsize::new(0)),
    ));

    let mut registry = Registry::new();
    registry.register(record.clone());
    registry.register(Arc::new(DelegateTool {
        record,
        child_model,
        effects: effects.clone(),
        events: events.clone(),
    }));

    let mut options = AgentOptions::new(parent_model);
    options.tools = Some(Arc::new(registry));
    options.events = Some(events);
    options.allowed_tools = vec!["record".to_string(), "delegate".to_string()];
    options.policy = Some(Arc::new(ParentPolicy));
    options.require_policy = true;
    options.require_tool_scope = true;
    options.max_steps = 6;
    let parent = Agent::new(options)?;
    let result = parent.run(
        &Session::new("chain-parent"),
        "run the representative chain",
    )?;

    let (denied_effect, denial_code) = run_denial()?;

    let effects = effects.lock().expect("effects").clone();
    let otel = otel_log.lock().expect("otel log").clone();
    let harmovela = harmovela_log.lock().expect("harmovela log").clone();
    Ok(Summary {
        output: result.output,
        effects,
        child_calls: child_calls.load(Ordering::SeqCst),
        otel,
        harmovela,
        denied_effect,
        denial_code,
    })
}

fn run_denial() -> Result<(usize, String)> {
    let effects = new_effects();
    let (_client, record) = mcp_record(effects.clone())?;
    let mut registry = Registry::new();
    registry.register(record);
    let model: Arc<dyn Model> = Arc::new(ScriptedModel::new(
        vec![vec![tool_call(
            "denied-record",
            "record",
            json!({"target": "safe"}),
        )]],
        "UNEXPECTED",
        Arc::new(AtomicUsize::new(0)),
    ));
    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(registry));
    options.allowed_tools = vec!["record".to_string()];
    options.policy = Some(Arc::new(ParentPolicy));
    options.middleware = vec![Box::new(BlockedEdit)];
    options.require_policy = true;
    options.require_tool_scope = true;
    options.max_steps = 2;
    let agent = Agent::new(options)?;
    match agent.run(&Session::new("chain-denial"), "call record") {
        Ok(_) => Err(PraxoError::new(
            "CHAIN_DENIAL",
            "representative chain: denial path unexpectedly succeeded",
        )),
        Err(error) => Ok((effect_count(&effects, "blocked"), error.code.to_string())),
    }
}

fn main() {
    let summary = match run_chain() {
        Ok(summary) => summary,
        Err(error) => {
            eprintln!("representative chain failed: {error}");
            std::process::exit(1);
        }
    };
    assert_eq!(summary.output, "DONE");
    assert_eq!(summary.effects.get("parent").copied().unwrap_or(0), 1);
    assert_eq!(summary.effects.get("child").copied().unwrap_or(0), 1);
    assert!(summary.child_calls >= 2);
    for name in ["praxo.run.started", "praxo.tool.call", "praxo.run.completed"] {
        assert!(summary.otel.iter().any(|item| item == name), "missing otel span {name}");
    }
    for kind in ["run.started", "tool.call", "run.completed"] {
        assert!(summary.harmovela.iter().any(|item| item == kind), "missing event {kind}");
    }
    assert_eq!(summary.denied_effect, 0);
    assert_eq!(summary.denial_code, "AGENT_POLICY_DENIED");
    println!("output: {}", summary.output);
    println!("effects: {:?}", summary.effects);
    println!("child calls: {}", summary.child_calls);
    println!("otel spans: {}", summary.otel.len());
    println!("harmovela events: {}", summary.harmovela.len());
    println!("denied effects: {}", summary.denied_effect);
}
