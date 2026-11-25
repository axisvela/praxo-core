use std::env;
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result as PraxoResult};
use praxo_core::model::{Message, Model, Request, Response, ToolCall, ToolSpec};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

const TENANT_SCOPE: &str = "acme";
const DEVICE_SCOPE: &str = "device-100";

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Stats {
    pub reads: usize,
    pub drafts: usize,
    pub executions: usize,
}

impl Stats {
    fn to_json(self) -> Value {
        json!({
            "reads": self.reads,
            "drafts": self.drafts,
            "executions": self.executions
        })
    }
}

#[derive(Debug)]
pub struct Review {
    report: Value,
    stats: Stats,
    trace: Vec<Value>,
}

impl Review {
    pub fn to_json(&self) -> Value {
        json!({
            "report": self.report,
            "agent": self.stats.to_json()
        })
    }
}

#[derive(Debug)]
pub struct ReviewFailure {
    pub code: String,
    pub message: String,
    pub stats: Stats,
    pub trace: Vec<Value>,
}

impl ReviewFailure {
    pub fn to_json(&self) -> Value {
        json!({
            "error": self.code,
            "message": self.message,
            "agent": self.stats.to_json(),
            "agent_trace": self.trace
        })
    }
}

trait GatewayAdapter: Send + Sync {
    fn read(&self, device: &str) -> PraxoResult<Value>;
}

struct FixtureGateway {
    simulate_failure: bool,
}

impl GatewayAdapter for FixtureGateway {
    fn read(&self, device: &str) -> PraxoResult<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "GATEWAY_READ_FAILED",
                "gateway telemetry adapter unavailable",
            ));
        }
        Ok(json!({
            "device_id": device,
            "temperature_c": 82,
            "pressure_kpa": 118.5,
            "link": "degraded",
            "firmware": "1.4.2",
            "source": "adapter_fixture"
        }))
    }
}

struct ReadGatewayTool {
    adapter: Arc<dyn GatewayAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadGatewayTool {
    fn name(&self) -> &str {
        "read_gateway"
    }

    fn description(&self) -> &str {
        "Read gateway telemetry through an application-owned adapter."
    }

    fn invoke(&self, args: &Map<String, Value>) -> PraxoResult<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let device = args
            .get("device_id")
            .and_then(Value::as_str)
            .unwrap_or(DEVICE_SCOPE);
        self.adapter.read(device)
    }
}

struct DraftActionTool {
    drafts: Arc<AtomicUsize>,
}

impl Tool for DraftActionTool {
    fn name(&self) -> &str {
        "draft_action"
    }

    fn description(&self) -> &str {
        "Draft a model-written review-only remediation; never writes to the device."
    }

    fn invoke(&self, args: &Map<String, Value>) -> PraxoResult<Value> {
        self.drafts.fetch_add(1, Ordering::SeqCst);
        Ok(json!({
            "remediation_id": "remediation-100",
            "device_id": args.get("device_id").cloned().unwrap_or(Value::Null),
            "action": args.get("action").cloned().unwrap_or(Value::Null),
            "diagnosis": args.get("diagnosis").cloned().unwrap_or(Value::Null),
            "rationale": args.get("rationale").cloned().unwrap_or(Value::Null),
            "status": "draft_only",
            "review_required": true,
            "executions": 0
        }))
    }
}

struct ExecuteActionTool {
    executions: Arc<AtomicUsize>,
}

impl Tool for ExecuteActionTool {
    fn name(&self) -> &str {
        "execute_remediation"
    }

    fn description(&self) -> &str {
        "Would execute remediation. Always denied in the agent path."
    }

    fn invoke(&self, args: &Map<String, Value>) -> PraxoResult<Value> {
        self.executions.fetch_add(1, Ordering::SeqCst);
        Ok(json!({
            "device_id": args.get("device_id").cloned().unwrap_or(Value::Null),
            "status": "executed"
        }))
    }
}

struct OpsPolicy {
    tenant: String,
}

impl Hook for OpsPolicy {
    fn authorize(&self, action: &Action) -> PraxoResult<Decision> {
        if self.tenant != TENANT_SCOPE {
            return Ok(Decision::deny("tenant mismatch"));
        }
        if action.kind == "model.generate" {
            return Ok(Decision::allow("ops generation"));
        }
        if action.kind != "tool.invoke" {
            return Ok(Decision::deny("unsupported action"));
        }
        let arguments = action.arguments.as_ref();
        let device = arguments
            .and_then(|args| args.get("device_id"))
            .and_then(Value::as_str);
        let action_name = arguments
            .and_then(|args| args.get("action"))
            .and_then(Value::as_str);
        let diagnosis = arguments
            .and_then(|args| args.get("diagnosis"))
            .and_then(Value::as_str)
            .unwrap_or("");
        let rationale = arguments
            .and_then(|args| args.get("rationale"))
            .and_then(Value::as_str)
            .unwrap_or("");
        if action.tool_name.as_deref() == Some("execute_remediation") {
            return Ok(Decision::deny(
                "execution requires an approved host workflow",
            ));
        }
        if device != Some(DEVICE_SCOPE) {
            return Ok(Decision::deny("only device-100 is in scope"));
        }
        match action.tool_name.as_deref() {
            Some("read_gateway") => Ok(Decision::allow("read-only telemetry")),
            Some("draft_action") => {
                if action_name == Some("review_remediation")
                    && !diagnosis.trim().is_empty()
                    && !rationale.trim().is_empty()
                {
                    Ok(Decision::allow("review-only remediation"))
                } else {
                    Ok(Decision::deny(
                        "review_remediation with diagnosis and rationale is required",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported tool")),
        }
    }
}

struct DeterministicModel {
    device: String,
    intent: String,
}

impl DeterministicModel {
    fn tool_response(id: &str, name: &str, arguments: Value) -> Response {
        let arguments = arguments.as_object().cloned().unwrap_or_default();
        Response {
            message: Message::assistant(
                "",
                vec![ToolCall {
                    id: id.to_string(),
                    name: name.to_string(),
                    arguments,
                }],
            ),
            ..Response::default()
        }
    }

    fn text_response(content: impl Into<String>) -> Response {
        Response {
            message: Message::assistant(content.into(), Vec::new()),
            ..Response::default()
        }
    }
}

impl Model for DeterministicModel {
    fn generate(&self, request: &Request) -> PraxoResult<Response> {
        let tools: Vec<&Message> = request
            .messages
            .iter()
            .filter(|message| message.role == "tool")
            .collect();
        if tools.is_empty() {
            if direct_execution(&self.intent) {
                return Ok(Self::tool_response(
                    "execute-1",
                    "execute_remediation",
                    json!({
                        "device_id": self.device,
                        "intent": self.intent
                    }),
                ));
            }
            return Ok(Self::tool_response(
                "signals-1",
                "read_gateway",
                json!({ "device_id": self.device }),
            ));
        }
        let first = tools[0]
            .content
            .as_deref()
            .and_then(|content| serde_json::from_str::<Value>(content).ok())
            .unwrap_or(Value::Null);
        if let Some(code) = first.get("error").and_then(Value::as_str) {
            return Ok(Self::text_response(code));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "draft-1",
                "draft_action",
                json!({
                    "device_id": self.device,
                    "action": "review_remediation",
                    "diagnosis": "gateway link is degraded with elevated temperature",
                    "rationale": "temperature_c 82 and link degraded exceed the review threshold"
                }),
            ));
        }
        let last = tools[tools.len() - 1]
            .content
            .as_deref()
            .and_then(|content| serde_json::from_str::<Value>(content).ok())
            .unwrap_or(Value::Null);
        let report = json!({
            "device": self.device,
            "signals": first,
            "remediation": last,
            "executions": 0
        });
        Ok(Self::text_response(report.to_string()))
    }
}

struct LiveModel {
    base_url: String,
    api_key: String,
    model: String,
    specs: Vec<ToolSpec>,
}

impl LiveModel {
    fn endpoint(&self) -> String {
        let base = self.base_url.trim_end_matches('/');
        if base.ends_with("/chat/completions") {
            base.to_string()
        } else {
            format!("{base}/chat/completions")
        }
    }

    fn payload(&self, request: &Request) -> Value {
        let messages = request
            .messages
            .iter()
            .map(message_payload)
            .collect::<Vec<Value>>();
        let mut body = Map::new();
        body.insert(
            "model".to_string(),
            json!(request.model.clone().unwrap_or_else(|| self.model.clone())),
        );
        body.insert("messages".to_string(), Value::Array(messages));
        if !request.tools.is_empty() {
            let tools = request
                .tools
                .iter()
                .map(|spec| {
                    json!({
                        "type": "function",
                        "function": {
                            "name": spec.name,
                            "description": spec.description,
                            "parameters": spec.parameters.clone().unwrap_or_else(|| {
                                json!({"type": "object", "properties": {}})
                                    .as_object()
                                    .cloned()
                                    .unwrap()
                            })
                        }
                    })
                })
                .collect::<Vec<Value>>();
            body.insert("tools".to_string(), Value::Array(tools));
        }
        Value::Object(body)
    }

    fn post(&self, payload: &Value) -> PraxoResult<Value> {
        let body = serde_json::to_string(payload)
            .map_err(|error| PraxoError::new("PROVIDER_JSON", error.to_string()))?;
        let curl = env::var("CURL").unwrap_or_else(|_| "curl".to_string());
        let mut command = Command::new(curl);
        command.args(["-sS", "-X", "POST", "-H", "Content-Type: application/json"]);
        if cfg!(windows) {
            command.arg("--ssl-no-revoke");
        }
        if !self.api_key.is_empty() {
            command.arg("-H");
            command.arg(format!("Authorization: Bearer {}", self.api_key));
        }
        command
            .args(["--max-time", "60", "--data-binary"])
            .arg(body)
            .args(["-w", "\n%{http_code}"])
            .arg(self.endpoint());
        let output = command
            .output()
            .map_err(|error| PraxoError::new("MODEL_HTTP", format!("curl failed: {error}")))?;
        if !output.status.success() {
            return Err(PraxoError::new(
                "MODEL_HTTP",
                format!(
                    "curl failed: {}",
                    String::from_utf8_lossy(&output.stderr).trim()
                ),
            ));
        }
        let text = String::from_utf8_lossy(&output.stdout);
        let index = text.rfind('\n').unwrap_or(text.len());
        let response_body = &text[..index];
        let code = text[index + 1..]
            .trim()
            .parse::<u16>()
            .map_err(|_| PraxoError::new("MODEL_HTTP", "provider returned no status"))?;
        if !(200..300).contains(&code) {
            return Err(PraxoError::new(
                "MODEL_HTTP",
                format!("provider returned HTTP {code}: {}", preview(response_body)),
            ));
        }
        serde_json::from_str(response_body).map_err(|error| {
            PraxoError::new(
                "PROVIDER_JSON",
                format!("provider returned invalid JSON: {error}"),
            )
        })
    }
}

impl Model for LiveModel {
    fn generate(&self, request: &Request) -> PraxoResult<Response> {
        let mut request = request.clone();
        request.tools = self.specs.clone();
        let data = self.post(&self.payload(&request))?;
        parse_response(&data)
    }
}

fn message_payload(message: &Message) -> Value {
    let mut out = Map::new();
    out.insert("role".to_string(), json!(message.role));
    out.insert(
        "content".to_string(),
        json!(message.content.clone().unwrap_or_default()),
    );
    if message.role == "assistant" && !message.tool_calls.is_empty() {
        let calls = message
            .tool_calls
            .iter()
            .map(|call| {
                json!({
                    "id": call.id,
                    "type": "function",
                    "function": {
                        "name": call.name,
                        "arguments": Value::Object(call.arguments.clone()).to_string()
                    }
                })
            })
            .collect::<Vec<Value>>();
        out.insert("tool_calls".to_string(), Value::Array(calls));
    }
    if message.role == "tool" {
        if let Some(id) = &message.tool_id {
            out.insert("tool_call_id".to_string(), json!(id));
        }
    }
    Value::Object(out)
}

fn parse_response(data: &Value) -> PraxoResult<Response> {
    let choice = data["choices"]
        .as_array()
        .and_then(|choices| choices.first())
        .ok_or_else(|| PraxoError::new("PROVIDER_JSON", "provider returned no choices"))?;
    let message = &choice["message"];
    let content = message["content"].as_str().unwrap_or("");
    let mut calls = Vec::new();
    if let Some(items) = message["tool_calls"].as_array() {
        for item in items {
            let function = &item["function"];
            let name = function["name"].as_str().unwrap_or("");
            let arguments = match &function["arguments"] {
                Value::String(raw) if !raw.is_empty() => serde_json::from_str::<Value>(raw)
                    .map_err(|error| {
                        PraxoError::new(
                            "PROVIDER_JSON",
                            format!("provider returned invalid tool arguments: {error}"),
                        )
                    })?,
                Value::Object(_) => function["arguments"].clone(),
                _ => Value::Object(Map::new()),
            };
            calls.push(ToolCall {
                id: item["id"].as_str().unwrap_or("").to_string(),
                name: name.to_string(),
                arguments: arguments.as_object().cloned().unwrap_or_default(),
            });
        }
    }
    let usage = &data["usage"];
    Ok(Response {
        message: Message::assistant(content, calls),
        usage: praxo_core::model::Usage {
            input_tokens: usage["prompt_tokens"].as_i64().unwrap_or(0),
            output_tokens: usage["completion_tokens"].as_i64().unwrap_or(0),
            cached_tokens: 0,
        },
        finish_reason: choice["finish_reason"].as_str().map(str::to_string),
    })
}

fn preview(value: &str) -> String {
    value.chars().take(512).collect()
}

struct TracingModel {
    inner: Arc<dyn Model>,
    steps: Mutex<Vec<Value>>,
}

impl TracingModel {
    fn new(inner: Arc<dyn Model>) -> Self {
        Self {
            inner,
            steps: Mutex::new(Vec::new()),
        }
    }

    fn steps(&self) -> Vec<Value> {
        self.steps
            .lock()
            .map(|steps| steps.clone())
            .unwrap_or_default()
    }
}

impl Model for TracingModel {
    fn generate(&self, request: &Request) -> PraxoResult<Response> {
        let result = self.inner.generate(request);
        let step = trace_step(request, result.as_ref().ok(), result.as_ref().err());
        if let Ok(mut steps) = self.steps.lock() {
            steps.push(step);
        }
        result
    }
}

fn trace_step(request: &Request, response: Option<&Response>, error: Option<&PraxoError>) -> Value {
    let mut tool_calls = Vec::new();
    let mut tool_results = Vec::new();
    for message in &request.messages {
        for call in &message.tool_calls {
            tool_calls.push(json!({
                "name": call.name,
                "arguments": call.arguments
            }));
        }
        if message.role == "tool" {
            tool_results.push(json!({
                "tool_id": message.tool_id,
                "content": message.content
            }));
        }
    }
    let model_output = match (response, error) {
        (Some(response), _) => {
            let output_calls: Vec<Value> = response
                .message
                .tool_calls
                .iter()
                .map(|call| {
                    json!({
                        "name": call.name,
                        "arguments": call.arguments
                    })
                })
                .collect();
            json!({
                "content": truncate(response.message.content.as_deref().unwrap_or(""), 1000),
                "tool_calls": output_calls
            })
        }
        (_, Some(error)) => json!({ "error": error.message }),
        _ => json!({}),
    };
    json!({
        "tool_calls": tool_calls,
        "tool_results": tool_results,
        "model_output": model_output
    })
}

fn truncate(value: &str, max: usize) -> String {
    if value.len() <= max {
        value.to_string()
    } else {
        format!("{}...", &value[..max])
    }
}

pub fn review(
    tenant: &str,
    device: &str,
    intent: &str,
    simulate_failure: bool,
) -> Result<Review, ReviewFailure> {
    review_with_options(tenant, device, intent, simulate_failure, None)
}

pub fn review_with_options(
    tenant: &str,
    device: &str,
    intent: &str,
    simulate_failure: bool,
    model_override: Option<Arc<dyn Model>>,
) -> Result<Review, ReviewFailure> {
    let reads = Arc::new(AtomicUsize::new(0));
    let drafts = Arc::new(AtomicUsize::new(0));
    let executions = Arc::new(AtomicUsize::new(0));
    let adapter: Arc<dyn GatewayAdapter> = Arc::new(FixtureGateway { simulate_failure });

    let mut registry = Registry::new();
    registry.register(Arc::new(ReadGatewayTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftActionTool {
        drafts: drafts.clone(),
    }));
    registry.register(Arc::new(ExecuteActionTool {
        executions: executions.clone(),
    }));

    let (base_model, mode): (Arc<dyn Model>, &str) = match model_override {
        Some(model) => (model, "injected"),
        None => match live_model() {
            Some(model) => (model, "live"),
            None => (
                Arc::new(DeterministicModel {
                    device: device.to_string(),
                    intent: intent.to_string(),
                }),
                "deterministic",
            ),
        },
    };
    let tracing = Arc::new(TracingModel::new(base_model));
    let tracing_model: Arc<dyn Model> = tracing.clone();

    let mut options = AgentOptions::new(tracing_model);
    options.tools = Some(Arc::new(registry));
    options.allowed_tools = vec![
        "read_gateway".to_string(),
        "draft_action".to_string(),
        "execute_remediation".to_string(),
    ];
    options.policy = Some(Arc::new(OpsPolicy {
        tenant: tenant.to_string(),
    }));
    options.require_policy = true;
    options.require_tool_scope = true;
    options.max_steps = 4;
    options.max_tokens = 60000;
    options.system_prompt = format!(
        "You are an edge operations copilot for tenant {tenant}. The only authorized device id is {DEVICE_SCOPE}. \
         Use that exact id in tool arguments; display names are not device ids. Search telemetry, diagnose, and \
         draft a review-only remediation. Never execute remediation; return JSON with device, signals, remediation, and executions."
    );

    let agent = match Agent::new(options) {
        Ok(agent) => agent,
        Err(error) => {
            return Err(ReviewFailure {
                code: "AGENT_RUNTIME_ERROR".to_string(),
                message: error.message,
                stats: Stats::default(),
                trace: tracing.steps(),
            });
        }
    };
    let mut session = Session::new(format!("rust-ai-ops-{tenant}-{device}"));
    session.tenant_id = tenant.to_string();
    let result = agent.run(&session, intent);
    let trace = tracing.steps();
    let stats = Stats {
        reads: reads.load(Ordering::SeqCst),
        drafts: drafts.load(Ordering::SeqCst),
        executions: executions.load(Ordering::SeqCst),
    };
    match result {
        Ok(run) => {
            let mut report = match parse_report(&run.output) {
                Some(report) => report,
                None => {
                    let code = if trace_has_tool_error(&trace) {
                        "TOOL_ERROR"
                    } else {
                        "AGENT_INVALID_OUTPUT"
                    };
                    return Err(ReviewFailure {
                        code: code.to_string(),
                        message: "agent did not return the required edge package".to_string(),
                        stats,
                        trace,
                    });
                }
            };
            normalize_report(&mut report, device, &trace);
            if !valid_report(&report) {
                return Err(ReviewFailure {
                    code: "AGENT_INVALID_OUTPUT".to_string(),
                    message: "agent did not return the required edge package".to_string(),
                    stats,
                    trace,
                });
            }
            report.insert("tenant".to_string(), json!(tenant));
            report.insert("model".to_string(), json!(mode));
            report.insert("agent_trace".to_string(), Value::Array(trace.clone()));
            Ok(Review {
                report: Value::Object(report),
                stats,
                trace,
            })
        }
        Err(error) => Err(ReviewFailure {
            code: map_error_code(&error),
            message: error.message,
            stats,
            trace,
        }),
    }
}

fn live_model() -> Option<Arc<dyn Model>> {
    let base_url = env::var("PRAXO_BASE_URL").ok()?;
    let model = env::var("PRAXO_MODEL").ok()?;
    if base_url.trim().is_empty() || model.trim().is_empty() {
        return None;
    }
    Some(Arc::new(LiveModel {
        base_url,
        api_key: env::var("PRAXO_API_KEY").unwrap_or_default(),
        model,
        specs: tool_specs(),
    }))
}

fn tool_specs() -> Vec<ToolSpec> {
    vec![
        ToolSpec {
            name: "read_gateway".to_string(),
            description: "Read gateway telemetry through an application-owned adapter.".to_string(),
            parameters: Some(params(json!({
                "type": "object",
                "required": ["device_id"],
                "properties": {"device_id": {"type": "string"}}
            }))),
            risk: Some("read".to_string()),
        },
        ToolSpec {
            name: "draft_action".to_string(),
            description:
                "Draft a model-written review-only remediation; never writes to the device."
                    .to_string(),
            parameters: Some(params(json!({
                "type": "object",
                "required": ["device_id", "action", "diagnosis", "rationale"],
                "properties": {
                    "device_id": {"type": "string"},
                    "action": {"type": "string", "enum": ["review_remediation"]},
                    "diagnosis": {"type": "string"},
                    "rationale": {"type": "string"}
                }
            }))),
            risk: Some("write".to_string()),
        },
        ToolSpec {
            name: "execute_remediation".to_string(),
            description: "Would execute remediation. Always denied in the agent path.".to_string(),
            parameters: Some(params(json!({
                "type": "object",
                "required": ["device_id", "intent"],
                "properties": {
                    "device_id": {"type": "string"},
                    "intent": {"type": "string"}
                }
            }))),
            risk: Some("write".to_string()),
        },
    ]
}

fn params(value: Value) -> Map<String, Value> {
    value.as_object().cloned().unwrap_or_default()
}

fn parse_report(output: &str) -> Option<Map<String, Value>> {
    if let Ok(Value::Object(report)) = serde_json::from_str::<Value>(output) {
        return Some(report);
    }
    let start = output.find('{')?;
    let end = output.rfind('}')?;
    if start >= end {
        return None;
    }
    match serde_json::from_str::<Value>(&output[start..=end]) {
        Ok(Value::Object(report)) => Some(report),
        _ => None,
    }
}

fn normalize_report(report: &mut Map<String, Value>, device: &str, trace: &[Value]) {
    let mut payloads = Vec::new();
    for step in trace {
        if let Some(results) = step.get("tool_results").and_then(Value::as_array) {
            for result in results {
                if let Some(content) = result.get("content").and_then(Value::as_str) {
                    if let Ok(Value::Object(payload)) = serde_json::from_str::<Value>(content) {
                        payloads.push(payload);
                    }
                }
            }
        }
    }
    if let Some(remediation) = find_payload(&payloads, "remediation_id") {
        report.insert("remediation".to_string(), Value::Object(remediation));
    }
    if let Some(signals) = find_payload(&payloads, "temperature_c") {
        report.insert("signals".to_string(), Value::Object(signals));
    }
    if let Some(review) = find_payload(&payloads, "review_id") {
        report.insert("review".to_string(), Value::Object(review));
    }
    report.insert("device".to_string(), json!(device));
    report.insert("executions".to_string(), json!(0));
}

fn find_payload(payloads: &[Map<String, Value>], key: &str) -> Option<Map<String, Value>> {
    payloads
        .iter()
        .find(|payload| payload.contains_key(key))
        .cloned()
}

fn valid_report(report: &Map<String, Value>) -> bool {
    ["device", "signals", "remediation", "executions"]
        .iter()
        .all(|key| report.contains_key(*key))
        && report
            .get("executions")
            .and_then(Value::as_i64)
            .map(|value| value == 0)
            .unwrap_or(false)
}

fn trace_has_tool_error(trace: &[Value]) -> bool {
    trace.iter().any(|step| {
        step.get("tool_results")
            .and_then(Value::as_array)
            .map(|results| {
                results.iter().any(|result| {
                    result
                        .get("content")
                        .and_then(Value::as_str)
                        .and_then(|content| serde_json::from_str::<Value>(content).ok())
                        .and_then(|payload| payload.get("error").cloned())
                        .is_some()
                })
            })
            .unwrap_or(false)
    })
}

fn map_error_code(error: &PraxoError) -> String {
    match error.code {
        "GATEWAY_READ_FAILED" => "TOOL_ERROR".to_string(),
        "AGENT_TOOL_NOT_ALLOWED" => "AGENT_POLICY_DENIED".to_string(),
        code => code.to_string(),
    }
}

fn direct_execution(intent: &str) -> bool {
    let lower = intent.to_lowercase();
    lower.contains("execute remediation") || lower.contains("remediate now")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn deterministic_model(device: &str, intent: &str) -> Arc<dyn Model> {
        Arc::new(DeterministicModel {
            device: device.to_string(),
            intent: intent.to_string(),
        })
    }

    fn run_case(
        tenant: &str,
        device: &str,
        intent: &str,
        simulate_failure: bool,
    ) -> Result<Review, ReviewFailure> {
        review_with_options(
            tenant,
            device,
            intent,
            simulate_failure,
            Some(deterministic_model(device, intent)),
        )
    }

    #[test]
    fn drafts_review_only_remediation() {
        let review = run_case(
            TENANT_SCOPE,
            DEVICE_SCOPE,
            "Investigate the gateway.",
            false,
        )
        .expect("success");
        let report = review.to_json()["report"].clone();
        assert_eq!(report["model"], "injected");
        assert_eq!(report["remediation"]["status"], "draft_only");
        assert!(report["remediation"]["diagnosis"].as_str().unwrap().len() > 0);
        assert!(report["remediation"]["rationale"].as_str().unwrap().len() > 0);
        assert_eq!(report["executions"], 0);
        assert_eq!(review.stats.reads, 1);
        assert_eq!(review.stats.drafts, 1);
        assert_eq!(review.stats.executions, 0);
        assert!(trace_has_tool(&review.trace, "read_gateway"));
        assert!(trace_has_tool(&review.trace, "draft_action"));
    }

    #[test]
    fn direct_remediation_is_denied() {
        let failure = run_case(
            TENANT_SCOPE,
            DEVICE_SCOPE,
            "Remediate now for device-100.",
            false,
        )
        .expect_err("direct remediation must fail");
        assert_eq!(failure.code, "AGENT_POLICY_DENIED");
        assert_eq!(failure.stats, Stats::default());
    }

    #[test]
    fn out_of_scope_device_is_denied() {
        let failure = run_case(TENANT_SCOPE, "device-200", "Investigate.", false)
            .expect_err("device-200 must be denied");
        assert_eq!(failure.code, "AGENT_POLICY_DENIED");
        assert_eq!(failure.stats, Stats::default());
    }

    #[test]
    fn tenant_mismatch_is_denied() {
        let failure = run_case("other", DEVICE_SCOPE, "Investigate.", false)
            .expect_err("tenant mismatch must be denied");
        assert_eq!(failure.code, "AGENT_POLICY_DENIED");
        assert_eq!(failure.stats, Stats::default());
    }

    #[test]
    fn gateway_failure_returns_tool_error() {
        let failure = run_case(TENANT_SCOPE, DEVICE_SCOPE, "Investigate.", true)
            .expect_err("adapter failure must fail");
        assert_eq!(failure.code, "TOOL_ERROR");
        assert_eq!(failure.stats.reads, 1);
        assert_eq!(failure.stats.drafts, 0);
    }

    #[test]
    fn invalid_model_output_is_rejected() {
        struct InvalidModel;
        impl Model for InvalidModel {
            fn generate(&self, _request: &Request) -> PraxoResult<Response> {
                Ok(Response {
                    message: Message::assistant("not-json", Vec::new()),
                    ..Response::default()
                })
            }
        }
        let failure = review_with_options(
            TENANT_SCOPE,
            DEVICE_SCOPE,
            "Investigate.",
            false,
            Some(Arc::new(InvalidModel)),
        )
        .expect_err("invalid output must fail");
        assert_eq!(failure.code, "AGENT_INVALID_OUTPUT");
        assert_eq!(failure.stats, Stats::default());
    }

    fn trace_has_tool(trace: &[Value], name: &str) -> bool {
        trace.iter().any(|step| {
            step.get("tool_calls")
                .and_then(Value::as_array)
                .map(|calls| calls.iter().any(|call| call["name"] == name))
                .unwrap_or(false)
                || step
                    .get("model_output")
                    .and_then(|output| output.get("tool_calls"))
                    .and_then(Value::as_array)
                    .map(|calls| calls.iter().any(|call| call["name"] == name))
                    .unwrap_or(false)
        })
    }
}
