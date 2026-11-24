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

const MINE_ID: &str = "mine-100";

struct FixtureModel {
    mine: String,
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
                "slope-1",
                "read_slope",
                json!({ "mine_id": self.mine }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "alert-1",
                "draft_alert",
                json!({ "mine_id": self.mine, "action": "draft_alert" }),
            ));
        }
        let slope = Self::tool_payload(&tools, 0);
        let alert = Self::tool_payload(&tools, 1);
        let report = json!({
            "slope": slope,
            "alert": alert,
            "policy": "read and draft only; collapse prediction and dispatch remain application-owned",
            "collapse_predictions": 0,
            "dispatches": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait SlopeAdapter: Send + Sync {
    fn read(&self, mine: &str) -> Result<Value>;
}

struct FixtureSlope {
    simulate_failure: bool,
}

impl SlopeAdapter for FixtureSlope {
    fn read(&self, mine: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "SLOPE_SOURCE_UNAVAILABLE",
                "slope telemetry unavailable",
            ));
        }
        Ok(json!({
            "mine_id": mine,
            "sensors": 3,
            "displacement_mm": 12.4,
            "threshold_mm": 10.0,
            "trend": "rising",
            "source": "slope_fixture"
        }))
    }
}

struct ReadSlopeTool {
    adapter: Arc<dyn SlopeAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadSlopeTool {
    fn name(&self) -> &str {
        "read_slope"
    }

    fn description(&self) -> &str {
        "Read fixed slope displacement indicators; no collapse prediction."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let mine = args
            .get("mine_id")
            .and_then(Value::as_str)
            .unwrap_or(MINE_ID);
        self.adapter.read(mine)
    }
}

struct DraftAlertTool;

impl Tool for DraftAlertTool {
    fn name(&self) -> &str {
        "draft_alert"
    }

    fn description(&self) -> &str {
        "Draft a review-only slope alert; never dispatches or predicts collapse."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let mine = args
            .get("mine_id")
            .and_then(Value::as_str)
            .unwrap_or(MINE_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_alert");
        Ok(json!({
            "alert_id": "slope-alert-100",
            "mine_id": mine,
            "action": action,
            "status": "draft_only",
            "review_required": true,
            "collapse_predictions": 0,
            "dispatches": 0
        }))
    }
}

struct SlopePolicy;

impl Hook for SlopePolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic slope review")),
            "tool.invoke" => {
                let mine = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("mine_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_slope") => mine == Some(MINE_ID),
                    Some("draft_alert") => mine == Some(MINE_ID) && action_name == Some("draft_alert"),
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("mine-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only mine-100 read and draft_alert are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(mine: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureSlope { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadSlopeTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftAlertTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        mine: mine.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_slope".to_string(), "draft_alert".to_string()];
    options.policy = Some(Arc::new(SlopePolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("mining-slope-{mine}")),
            "Read the fixed slope indicators and draft a review-only alert.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(MINE_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["slope"]["mine_id"], MINE_ID);
    assert_eq!(report["slope"]["sensors"], 3);
    assert_eq!(report["slope"]["displacement_mm"], 12.4);
    assert_eq!(report["alert"]["status"], "draft_only");
    assert_eq!(report["alert"]["review_required"], true);
    assert_eq!(report["collapse_predictions"], 0);
    assert_eq!(report["dispatches"], 0);
    assert_eq!(reads, 1);
    println!("success: mine-100 sensors=3 displacement_mm=12.4 status=draft_only predictions=0 reads=1");

    let (denied, denied_reads) = review("mine-200", false);
    let denied = denied.expect_err("out-of-scope mine must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(MINE_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "SLOPE_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let mine = args
        .windows(2)
        .find(|pair| pair[0] == "--mine")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| MINE_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&mine, simulate_failure) {
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
