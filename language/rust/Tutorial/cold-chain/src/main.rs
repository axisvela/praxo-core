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

const SHIPMENT_ID: &str = "cold-100";

struct FixtureModel {
    shipment: String,
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
                "cold-1",
                "read_shipment",
                json!({ "shipment_id": self.shipment }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "review-1",
                "draft_review",
                json!({ "shipment_id": self.shipment, "action": "draft_transfer_review" }),
            ));
        }
        let shipment = Self::tool_payload(&tools, 0);
        let review = Self::tool_payload(&tools, 1);
        let report = json!({
            "shipment": shipment,
            "review": review,
            "policy": "read and draft only; refrigeration changes remain application-owned",
            "refrigeration_changes": 0,
            "clinical_guarantees": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait ColdAdapter: Send + Sync {
    fn read(&self, shipment: &str) -> Result<Value>;
}

struct FixtureCold {
    simulate_failure: bool,
}

impl ColdAdapter for FixtureCold {
    fn read(&self, shipment: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "COLD_SOURCE_UNAVAILABLE",
                "cold-chain telemetry unavailable",
            ));
        }
        Ok(json!({
            "shipment_id": shipment,
            "sensors": 2,
            "readings": 6,
            "min_c": -2.0,
            "max_c": 9.5,
            "threshold_c": 8.0,
            "excursion_minutes": 25,
            "source": "cold_fixture"
        }))
    }
}

struct ReadShipmentTool {
    adapter: Arc<dyn ColdAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadShipmentTool {
    fn name(&self) -> &str {
        "read_shipment"
    }

    fn description(&self) -> &str {
        "Compute fixed cold-chain excursions; no refrigeration access."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let shipment = args
            .get("shipment_id")
            .and_then(Value::as_str)
            .unwrap_or(SHIPMENT_ID);
        self.adapter.read(shipment)
    }
}

struct DraftReviewTool;

impl Tool for DraftReviewTool {
    fn name(&self) -> &str {
        "draft_review"
    }

    fn description(&self) -> &str {
        "Draft a review-only cargo transfer recommendation; never changes refrigeration."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let shipment = args
            .get("shipment_id")
            .and_then(Value::as_str)
            .unwrap_or(SHIPMENT_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_transfer_review");
        Ok(json!({
            "review_id": "cold-review-100",
            "shipment_id": shipment,
            "action": action,
            "recommendation": "inspect cargo before transfer",
            "status": "draft_only",
            "review_required": true,
            "refrigeration_changes": 0,
            "clinical_guarantees": 0
        }))
    }
}

struct ColdPolicy;

impl Hook for ColdPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic cold-chain review")),
            "tool.invoke" => {
                let shipment = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("shipment_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_shipment") => shipment == Some(SHIPMENT_ID),
                    Some("draft_review") => {
                        shipment == Some(SHIPMENT_ID) && action_name == Some("draft_transfer_review")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("cold-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only cold-100 read and draft_transfer_review are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(shipment: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureCold { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadShipmentTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftReviewTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        shipment: shipment.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_shipment".to_string(), "draft_review".to_string()];
    options.policy = Some(Arc::new(ColdPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("cold-chain-{shipment}")),
            "Analyze the fixed cold-chain excursions and draft a review-only transfer review.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(SHIPMENT_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["shipment"]["shipment_id"], SHIPMENT_ID);
    assert_eq!(report["shipment"]["max_c"], 9.5);
    assert_eq!(report["shipment"]["excursion_minutes"], 25);
    assert_eq!(report["review"]["status"], "draft_only");
    assert_eq!(report["review"]["review_required"], true);
    assert_eq!(report["refrigeration_changes"], 0);
    assert_eq!(report["clinical_guarantees"], 0);
    assert_eq!(reads, 1);
    println!("success: cold-100 max_c=9.5 excursion_minutes=25 status=draft_only changes=0 reads=1");

    let (denied, denied_reads) = review("cold-200", false);
    let denied = denied.expect_err("out-of-scope shipment must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(SHIPMENT_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "COLD_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let shipment = args
        .windows(2)
        .find(|pair| pair[0] == "--shipment")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| SHIPMENT_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&shipment, simulate_failure) {
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
