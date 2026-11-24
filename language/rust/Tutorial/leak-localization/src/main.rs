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

const NETWORK_ID: &str = "network-100";

struct FixtureModel {
    network: String,
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
                "anomalies-1",
                "read_anomalies",
                json!({ "network_id": self.network }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "inspection-1",
                "draft_inspection",
                json!({ "network_id": self.network, "action": "draft_inspection" }),
            ));
        }
        let anomalies = Self::tool_payload(&tools, 0);
        let inspection = Self::tool_payload(&tools, 1);
        let report = json!({
            "anomalies": anomalies,
            "inspection": inspection,
            "policy": "rank and draft only; valve isolation and field dispatch remain application-owned",
            "valve_commands": 0,
            "dispatches": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait NetworkAdapter: Send + Sync {
    fn read(&self, network: &str) -> Result<Value>;
}

struct FixtureNetwork {
    simulate_failure: bool,
}

impl NetworkAdapter for FixtureNetwork {
    fn read(&self, network: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "NETWORK_SOURCE_UNAVAILABLE",
                "pressure telemetry unavailable",
            ));
        }
        Ok(json!({
            "network_id": network,
            "segments": 5,
            "anomalies": 2,
            "ranked": ["seg-3", "seg-1"],
            "confidence": "medium",
            "source": "network_fixture"
        }))
    }
}

struct ReadAnomaliesTool {
    adapter: Arc<dyn NetworkAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadAnomaliesTool {
    fn name(&self) -> &str {
        "read_anomalies"
    }

    fn description(&self) -> &str {
        "Rank fixed pressure anomalies; no valve access or dispatch."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let network = args
            .get("network_id")
            .and_then(Value::as_str)
            .unwrap_or(NETWORK_ID);
        self.adapter.read(network)
    }
}

struct DraftInspectionTool;

impl Tool for DraftInspectionTool {
    fn name(&self) -> &str {
        "draft_inspection"
    }

    fn description(&self) -> &str {
        "Draft a review-only inspection list; never isolates valves or dispatches."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let network = args
            .get("network_id")
            .and_then(Value::as_str)
            .unwrap_or(NETWORK_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_inspection");
        Ok(json!({
            "inspection_id": "leak-inspection-100",
            "network_id": network,
            "action": action,
            "inspections": 2,
            "status": "draft_only",
            "review_required": true,
            "valve_commands": 0,
            "dispatches": 0
        }))
    }
}

struct NetworkPolicy;

impl Hook for NetworkPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic leak ranking")),
            "tool.invoke" => {
                let network = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("network_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_anomalies") => network == Some(NETWORK_ID),
                    Some("draft_inspection") => {
                        network == Some(NETWORK_ID) && action_name == Some("draft_inspection")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("network-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only network-100 read and draft_inspection are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(network: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureNetwork { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadAnomaliesTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftInspectionTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        network: network.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_anomalies".to_string(), "draft_inspection".to_string()];
    options.policy = Some(Arc::new(NetworkPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("leak-localization-{network}")),
            "Rank the fixed pressure anomalies and draft a review-only inspection list.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(NETWORK_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["anomalies"]["network_id"], NETWORK_ID);
    assert_eq!(report["anomalies"]["segments"], 5);
    assert_eq!(report["anomalies"]["anomalies"], 2);
    assert_eq!(report["inspection"]["status"], "draft_only");
    assert_eq!(report["inspection"]["review_required"], true);
    assert_eq!(report["valve_commands"], 0);
    assert_eq!(report["dispatches"], 0);
    assert_eq!(reads, 1);
    println!("success: network-100 segments=5 anomalies=2 status=draft_only valve_commands=0 reads=1");

    let (denied, denied_reads) = review("network-200", false);
    let denied = denied.expect_err("out-of-scope network must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(NETWORK_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "NETWORK_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let network = args
        .windows(2)
        .find(|pair| pair[0] == "--network")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| NETWORK_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&network, simulate_failure) {
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
