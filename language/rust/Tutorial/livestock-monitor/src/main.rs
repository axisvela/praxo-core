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

const HERD_ID: &str = "herd-100";

struct FixtureModel {
    herd: String,
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
                "herd-1",
                "read_herd",
                json!({ "herd_id": self.herd }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "request-1",
                "draft_request",
                json!({ "herd_id": self.herd, "action": "draft_review_request" }),
            ));
        }
        let herd = Self::tool_payload(&tools, 0);
        let request_payload = Self::tool_payload(&tools, 1);
        let report = json!({
            "herd": herd,
            "request": request_payload,
            "policy": "read and draft only; veterinary diagnosis and feeding remain application-owned",
            "diagnoses": 0,
            "feed_controls": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait HerdAdapter: Send + Sync {
    fn read(&self, herd: &str) -> Result<Value>;
}

struct FixtureHerd {
    simulate_failure: bool,
}

impl HerdAdapter for FixtureHerd {
    fn read(&self, herd: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "HERD_SOURCE_UNAVAILABLE",
                "herd observations unavailable",
            ));
        }
        Ok(json!({
            "herd_id": herd,
            "animals": 40,
            "flagged": 2,
            "symptom": "reduced_feed",
            "confidence": "low",
            "source": "herd_fixture"
        }))
    }
}

struct ReadHerdTool {
    adapter: Arc<dyn HerdAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadHerdTool {
    fn name(&self) -> &str {
        "read_herd"
    }

    fn description(&self) -> &str {
        "Summarize fixed animal observations; no veterinary diagnosis."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let herd = args
            .get("herd_id")
            .and_then(Value::as_str)
            .unwrap_or(HERD_ID);
        self.adapter.read(herd)
    }
}

struct DraftRequestTool;

impl Tool for DraftRequestTool {
    fn name(&self) -> &str {
        "draft_request"
    }

    fn description(&self) -> &str {
        "Draft a review-only veterinary request; never diagnoses or controls feeding."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let herd = args
            .get("herd_id")
            .and_then(Value::as_str)
            .unwrap_or(HERD_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_review_request");
        Ok(json!({
            "request_id": "vet-request-100",
            "herd_id": herd,
            "action": action,
            "animal_count": 2,
            "status": "draft_only",
            "review_required": true,
            "diagnoses": 0,
            "feed_controls": 0
        }))
    }
}

struct HerdPolicy;

impl Hook for HerdPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic livestock review")),
            "tool.invoke" => {
                let herd = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("herd_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_herd") => herd == Some(HERD_ID),
                    Some("draft_request") => {
                        herd == Some(HERD_ID) && action_name == Some("draft_review_request")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("herd-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only herd-100 read and draft_review_request are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(herd: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureHerd { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadHerdTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftRequestTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        herd: herd.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_herd".to_string(), "draft_request".to_string()];
    options.policy = Some(Arc::new(HerdPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("livestock-monitor-{herd}")),
            "Summarize the fixed herd observations and draft a review-only request.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(HERD_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["herd"]["herd_id"], HERD_ID);
    assert_eq!(report["herd"]["animals"], 40);
    assert_eq!(report["herd"]["flagged"], 2);
    assert_eq!(report["request"]["status"], "draft_only");
    assert_eq!(report["request"]["review_required"], true);
    assert_eq!(report["diagnoses"], 0);
    assert_eq!(report["feed_controls"], 0);
    assert_eq!(reads, 1);
    println!("success: herd-100 animals=40 flagged=2 status=draft_only diagnoses=0 reads=1");

    let (denied, denied_reads) = review("herd-200", false);
    let denied = denied.expect_err("out-of-scope herd must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(HERD_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "HERD_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let herd = args
        .windows(2)
        .find(|pair| pair[0] == "--herd")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| HERD_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&herd, simulate_failure) {
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
