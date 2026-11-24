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

const ROBOT_ID: &str = "robot-100";

struct FixtureModel {
    robot: String,
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
                "state-1",
                "read_state",
                json!({ "robot_id": self.robot }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "action-1",
                "draft_action",
                json!({ "robot_id": self.robot, "action": "draft_action" }),
            ));
        }
        let state = Self::tool_payload(&tools, 0);
        let action = Self::tool_payload(&tools, 1);
        let report = json!({
            "state": state,
            "action": action,
            "policy": "observe and draft only; hardware commands remain application-owned",
            "hardware_commands": 0,
            "safety_claims": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait RobotAdapter: Send + Sync {
    fn read(&self, robot: &str) -> Result<Value>;
}

struct FixtureRobot {
    simulate_failure: bool,
}

impl RobotAdapter for FixtureRobot {
    fn read(&self, robot: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "ROBOT_SOURCE_UNAVAILABLE",
                "robot state unavailable",
            ));
        }
        Ok(json!({
            "robot_id": robot,
            "observation_age_ms": 200,
            "fresh": true,
            "joints_ok": true,
            "workspace": "kitchen",
            "source": "robot_fixture"
        }))
    }
}

struct ReadStateTool {
    adapter: Arc<dyn RobotAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadStateTool {
    fn name(&self) -> &str {
        "read_state"
    }

    fn description(&self) -> &str {
        "Observe fixed robot state with freshness; no hardware access."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let robot = args
            .get("robot_id")
            .and_then(Value::as_str)
            .unwrap_or(ROBOT_ID);
        self.adapter.read(robot)
    }
}

struct DraftActionTool;

impl Tool for DraftActionTool {
    fn name(&self) -> &str {
        "draft_action"
    }

    fn description(&self) -> &str {
        "Draft a bounded review-only robot action; never commands hardware."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let robot = args
            .get("robot_id")
            .and_then(Value::as_str)
            .unwrap_or(ROBOT_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_action");
        Ok(json!({
            "action_id": "robot-action-100",
            "robot_id": robot,
            "action": action,
            "proposed": "pick",
            "authority": "bounded",
            "cancel_required": true,
            "status": "draft_only",
            "review_required": true,
            "hardware_commands": 0,
            "safety_claims": 0
        }))
    }
}

struct RobotPolicy;

impl Hook for RobotPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic robot planning")),
            "tool.invoke" => {
                let robot = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("robot_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_state") => robot == Some(ROBOT_ID),
                    Some("draft_action") => robot == Some(ROBOT_ID) && action_name == Some("draft_action"),
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("robot-100 observe and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only robot-100 observe and draft_action are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(robot: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureRobot { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadStateTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftActionTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        robot: robot.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_state".to_string(), "draft_action".to_string()];
    options.policy = Some(Arc::new(RobotPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("household-robot-{robot}")),
            "Observe the fixed robot state and draft a review-only bounded action.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(ROBOT_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["state"]["robot_id"], ROBOT_ID);
    assert_eq!(report["state"]["observation_age_ms"], 200);
    assert_eq!(report["state"]["fresh"], true);
    assert_eq!(report["action"]["status"], "draft_only");
    assert_eq!(report["action"]["authority"], "bounded");
    assert_eq!(report["action"]["cancel_required"], true);
    assert_eq!(report["hardware_commands"], 0);
    assert_eq!(report["safety_claims"], 0);
    assert_eq!(reads, 1);
    println!("success: robot-100 age_ms=200 fresh=true authority=bounded status=draft_only commands=0 reads=1");

    let (denied, denied_reads) = review("robot-200", false);
    let denied = denied.expect_err("out-of-scope robot must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(ROBOT_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "ROBOT_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let robot = args
        .windows(2)
        .find(|pair| pair[0] == "--robot")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| ROBOT_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&robot, simulate_failure) {
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
