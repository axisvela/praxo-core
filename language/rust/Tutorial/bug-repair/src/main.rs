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

const BUG_ID: &str = "bug-100";

struct FixtureModel {
    bug: String,
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

    fn payload(messages: &[&Message], index: usize) -> Value {
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
                "repair-1",
                "inspect_bug",
                json!({ "bug_id": self.bug, "action": "repair" }),
            ));
        }
        let repair = Self::payload(&tools, 0);
        let report = json!({
            "stage": "patch_drafted",
            "repair": repair,
            "pr_created": false,
            "writes": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

struct InspectBugTool {
    bug: String,
    simulate_failure: bool,
    reads: Arc<AtomicUsize>,
}

impl Tool for InspectBugTool {
    fn name(&self) -> &str {
        "inspect_bug"
    }

    fn description(&self) -> &str {
        "Reproduce a fixed bug, draft a patch and rerun the fixture test."
    }

    fn invoke(&self, _arguments: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        if self.simulate_failure {
            return Err(PraxoError::new(
                "BUG_SOURCE_UNAVAILABLE",
                "synthetic bug fixture unavailable",
            ));
        }
        Ok(json!({
            "bug_id": self.bug,
            "reproduced": true,
            "failing_test": "test_charge",
            "patch": "diff --git a/charge.rs b/charge.rs",
            "rerun": "pass",
            "status": "draft_only",
            "review_required": true,
            "writes": 0,
            "source": "bug_fixture"
        }))
    }
}

struct Policy {
    reads: Arc<AtomicUsize>,
}

impl Hook for Policy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind == "model.generate" {
            return Ok(Decision::allow("deterministic repair review"));
        }
        if action.kind != "tool.invoke" {
            return Ok(Decision::deny("unsupported action"));
        }
        let arguments = action.arguments.as_ref();
        let bug = arguments
            .and_then(|values| values.get("bug_id"))
            .and_then(Value::as_str)
            .unwrap_or("");
        let action_name = arguments
            .and_then(|values| values.get("action"))
            .and_then(Value::as_str)
            .unwrap_or("");
        if bug != BUG_ID {
            return Ok(Decision::deny("only bug-100 is in scope"));
        }
        if action.tool_name.as_deref() == Some("inspect_bug") && action_name == "repair" {
            return Ok(Decision::allow("bug-100 repair draft only"));
        }
        Ok(Decision::deny("only a review-only repair draft is allowed"))
    }
}

fn run_case(bug: &str, simulate_failure: bool) -> Result<(String, usize)> {
    let reads = Arc::new(AtomicUsize::new(0));
    let mut registry = Registry::new();
    registry.register(Arc::new(InspectBugTool {
        bug: bug.to_string(),
        simulate_failure,
        reads: reads.clone(),
    }));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        bug: bug.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.allowed_tools = vec!["inspect_bug".to_string()];
    options.max_steps = 3;
    options.policy = Some(Arc::new(Policy { reads: reads.clone() }));
    options.require_policy = true;
    options.require_tool_scope = true;
    let result = Agent::new(options)?.run(
        &Session::new("bug-repair"),
        "Reproduce the fixed bug, draft a patch and rerun the fixture test.",
    )?;
    Ok((result.output, reads.load(Ordering::SeqCst)))
}

fn run_tests() -> Result<()> {
    let (output, reads) = run_case(BUG_ID, false)?;
    let report: Value = serde_json::from_str(&output)
        .map_err(|error| PraxoError::new("INVALID_REPORT", error.to_string()))?;
    if reads != 1
        || report["repair"]["reproduced"] != json!(true)
        || report["repair"]["rerun"] != json!("pass")
        || report["repair"]["status"] != json!("draft_only")
        || report["writes"] != json!(0)
        || report["pr_created"] != json!(false)
    {
        return Err(PraxoError::new("SUCCESS_FAILED", output));
    }
    println!("success: bug-100 reproduced=yes rerun=pass status=draft_only writes=0 reads=1");

    let denied = run_case("bug-200", false);
    match denied {
        Err(error) if error.code == "AGENT_POLICY_DENIED" => {}
        _ => return Err(PraxoError::new("DENY_FAILED", "expected policy denial")),
    }
    println!("deny: AGENT_POLICY_DENIED reads=0");

    match run_case(BUG_ID, true) {
        Err(error) if error.code == "BUG_SOURCE_UNAVAILABLE" => {}
        _ => return Err(PraxoError::new("FAILURE_FAILED", "expected source failure")),
    }
    println!("failure: BUG_SOURCE_UNAVAILABLE reads=1");
    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        if let Err(error) = run_tests() {
            eprintln!("{error}");
            process::exit(1);
        }
        return;
    }
    let index = args.iter().position(|arg| arg == "--bug");
    let bug = index
        .and_then(|position| args.get(position + 1))
        .map(String::as_str)
        .unwrap_or(BUG_ID);
    match run_case(bug, args.iter().any(|arg| arg == "--simulate-failure")) {
        Ok((output, reads)) => println!("{output}\nreads={reads}"),
        Err(error) => {
            eprintln!("{error}");
            process::exit(if error.code == "AGENT_POLICY_DENIED" { 2 } else { 1 });
        }
    }
}
