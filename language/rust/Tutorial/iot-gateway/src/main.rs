use std::env;
use std::process;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

const DEVICE_ID: &str = "device-100";

struct FixtureModel {
    device: String,
}

impl FixtureModel {
    fn tool_response(id: &str, name: &str, arguments: Value) -> Response {
        let arguments = match arguments {
            Value::Object(map) => map,
            _ => Map::new(),
        };
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

    fn tool_payload(messages: &[&Message], index: usize) -> Value {
        messages
            .get(index)
            .and_then(|message| message.content.as_deref())
            .and_then(|content| serde_json::from_str(content).ok())
            .unwrap_or(Value::Null)
    }
}

impl Model for FixtureModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        let tools: Vec<&Message> = request
            .messages
            .iter()
            .filter(|message| message.role == "tool")
            .collect();
        if tools.is_empty() {
            return Ok(Self::tool_response(
                "read-1",
                "read_gateway",
                json!({ "device_id": self.device }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "draft-1",
                "draft_action",
                json!({
                    "device_id": self.device,
                    "action": "open_ticket",
                    "reason": "temperature above threshold"
                }),
            ));
        }
        let gateway = Self::tool_payload(&tools, 0);
        let draft = Self::tool_payload(&tools, 1);
        let report = json!({
            "gateway": gateway,
            "draft": draft,
            "policy": "read and draft only; device writes remain application-owned",
            "device_writes": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait GatewayAdapter: Send + Sync {
    fn read(&self, device: &str) -> Result<Value>;
}

struct FixtureGateway {
    simulate_failure: bool,
}

impl GatewayAdapter for FixtureGateway {
    fn read(&self, device: &str) -> Result<Value> {
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
        "Read gateway telemetry through an application-owned adapter contract."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let device = args
            .get("device_id")
            .and_then(Value::as_str)
            .unwrap_or(DEVICE_ID);
        self.adapter.read(device)
    }
}

struct DraftActionTool;

impl Tool for DraftActionTool {
    fn name(&self) -> &str {
        "draft_action"
    }

    fn description(&self) -> &str {
        "Draft an operator review action without performing a device write."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let device = args
            .get("device_id")
            .and_then(Value::as_str)
            .unwrap_or(DEVICE_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("open_ticket");
        Ok(json!({
            "draft_id": "draft-100",
            "device_id": device,
            "action": action,
            "status": "draft_only",
            "review_required": true,
            "device_writes": 0
        }))
    }
}

struct GatewayPolicy;

impl Hook for GatewayPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic gateway diagnosis")),
            "tool.invoke" => {
                let device = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("device_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_gateway") => device == Some(DEVICE_ID),
                    Some("draft_action") => {
                        device == Some(DEVICE_ID) && action_name == Some("open_ticket")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("device-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only device-100 read and draft review are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(device: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureGateway { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadGatewayTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftActionTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        device: device.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_gateway".to_string(), "draft_action".to_string()];
    options.policy = Some(Arc::new(GatewayPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("iot-gateway-{device}")),
            "Diagnose the fixed gateway telemetry and draft an operator review action.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(DEVICE_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["gateway"]["device_id"], DEVICE_ID);
    assert_eq!(report["gateway"]["link"], "degraded");
    assert_eq!(report["gateway"]["temperature_c"], 82);
    assert_eq!(report["draft"]["status"], "draft_only");
    assert_eq!(report["draft"]["review_required"], true);
    assert_eq!(report["draft"]["device_writes"], 0);
    assert_eq!(reads, 1);
    println!(
        "success: device-100 link=degraded action=open_ticket status=draft_only writes=0 reads=1"
    );

    let (denied, denied_reads) = review("device-200", false);
    let denied = denied.expect_err("out-of-scope device must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(DEVICE_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "GATEWAY_READ_FAILED");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let device = args
        .windows(2)
        .find(|pair| pair[0] == "--device")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| DEVICE_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&device, simulate_failure) {
        (Ok(report), reads) => {
            println!("{report}");
            eprintln!("reads={reads}");
        }
        (Err(error), reads) => {
            eprintln!("error: {}: {} reads={reads}", error.code, error.message);
            process::exit(if error.code == "AGENT_POLICY_DENIED" {
                2
            } else {
                1
            });
        }
    }
}
