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

const LAB_ID: &str = "lab-100";

struct FixtureModel {
    lab: String,
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
                "loop-1",
                "read_loop",
                json!({ "lab_id": self.lab }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "plan-1",
                "draft_plan",
                json!({ "lab_id": self.lab, "action": "draft_next_parameters" }),
            ));
        }
        let loop_state = Self::tool_payload(&tools, 0);
        let plan = Self::tool_payload(&tools, 1);
        let report = json!({
            "loop": loop_state,
            "plan": plan,
            "policy": "simulate and draft only; laboratory actuators and chemicals remain application-owned",
            "actuators": 0,
            "chemicals": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait LabAdapter: Send + Sync {
    fn read(&self, lab: &str) -> Result<Value>;
}

struct FixtureLab {
    simulate_failure: bool,
}

impl LabAdapter for FixtureLab {
    fn read(&self, lab: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "LAB_SOURCE_UNAVAILABLE",
                "experiment loop unavailable",
            ));
        }
        Ok(json!({
            "lab_id": lab,
            "iterations": 3,
            "parameters": { "temperature_c": 80, "time_min": 30 },
            "best_result": 0.72,
            "limits_ok": true,
            "source": "lab_fixture"
        }))
    }
}

struct ReadLoopTool {
    adapter: Arc<dyn LabAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadLoopTool {
    fn name(&self) -> &str {
        "read_loop"
    }

    fn description(&self) -> &str {
        "Replay a fixed parameter/result loop; no laboratory actuator."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let lab = args
            .get("lab_id")
            .and_then(Value::as_str)
            .unwrap_or(LAB_ID);
        self.adapter.read(lab)
    }
}

struct DraftPlanTool;

impl Tool for DraftPlanTool {
    fn name(&self) -> &str {
        "draft_plan"
    }

    fn description(&self) -> &str {
        "Draft review-only next parameters; never actuates or handles chemicals."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let lab = args
            .get("lab_id")
            .and_then(Value::as_str)
            .unwrap_or(LAB_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_next_parameters");
        Ok(json!({
            "plan_id": "lab-plan-100",
            "lab_id": lab,
            "action": action,
            "iteration": 4,
            "parameters": { "temperature_c": 85, "time_min": 25 },
            "status": "draft_only",
            "review_required": true,
            "actuators": 0,
            "chemicals": 0
        }))
    }
}

struct LabPolicy;

impl Hook for LabPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic lab loop")),
            "tool.invoke" => {
                let lab = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("lab_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_loop") => lab == Some(LAB_ID),
                    Some("draft_plan") => {
                        lab == Some(LAB_ID) && action_name == Some("draft_next_parameters")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("lab-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only lab-100 read and draft_next_parameters are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(lab: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureLab { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadLoopTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftPlanTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        lab: lab.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_loop".to_string(), "draft_plan".to_string()];
    options.policy = Some(Arc::new(LabPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("lab-loop-{lab}")),
            "Replay the fixed experiment loop and draft review-only next parameters.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(LAB_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["loop"]["lab_id"], LAB_ID);
    assert_eq!(report["loop"]["iterations"], 3);
    assert_eq!(report["loop"]["best_result"], 0.72);
    assert_eq!(report["plan"]["status"], "draft_only");
    assert_eq!(report["plan"]["iteration"], 4);
    assert_eq!(report["actuators"], 0);
    assert_eq!(report["chemicals"], 0);
    assert_eq!(reads, 1);
    println!("success: lab-100 iterations=3 best_result=0.72 status=draft_only actuators=0 reads=1");

    let (denied, denied_reads) = review("lab-200", false);
    let denied = denied.expect_err("out-of-scope lab must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(LAB_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "LAB_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let lab = args
        .windows(2)
        .find(|pair| pair[0] == "--lab")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| LAB_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&lab, simulate_failure) {
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
