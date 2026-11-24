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

const REVIEW_ID: &str = "review-100";

struct FixtureModel {
    review: String,
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
                "review-1",
                "review_diff",
                json!({ "review_id": self.review, "action": "draft" }),
            ));
        }
        let review = Self::payload(&tools, 0);
        let report = json!({
            "stage": "review_drafted",
            "review": review,
            "comments_posted": 0,
            "writes": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

struct ReviewDiffTool {
    review: String,
    simulate_failure: bool,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReviewDiffTool {
    fn name(&self) -> &str {
        "review_diff"
    }

    fn description(&self) -> &str {
        "Review a fixed diff and dependency manifest; draft comments only."
    }

    fn invoke(&self, _arguments: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        if self.simulate_failure {
            return Err(PraxoError::new(
                "DIFF_UNAVAILABLE",
                "synthetic diff fixture unavailable",
            ));
        }
        Ok(json!({
            "review_id": self.review,
            "files": 2,
            "findings": 2,
            "license_issue": true,
            "uncertainty": "license metadata incomplete",
            "status": "draft_only",
            "review_required": true,
            "comments_posted": 0,
            "source": "diff_fixture"
        }))
    }
}

struct Policy;

impl Hook for Policy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind == "model.generate" {
            return Ok(Decision::allow("deterministic review"));
        }
        if action.kind != "tool.invoke" {
            return Ok(Decision::deny("unsupported action"));
        }
        let arguments = action.arguments.as_ref();
        let review = arguments
            .and_then(|values| values.get("review_id"))
            .and_then(Value::as_str)
            .unwrap_or("");
        let draft = arguments
            .and_then(|values| values.get("action"))
            .and_then(Value::as_str)
            .unwrap_or("");
        if review != REVIEW_ID {
            return Ok(Decision::deny("only review-100 is in scope"));
        }
        if action.tool_name.as_deref() == Some("review_diff") && draft == "draft" {
            return Ok(Decision::allow("review-100 draft comments only"));
        }
        Ok(Decision::deny("only a review-only draft is allowed"))
    }
}

fn run_case(review: &str, simulate_failure: bool) -> Result<(String, usize)> {
    let reads = Arc::new(AtomicUsize::new(0));
    let mut registry = Registry::new();
    registry.register(Arc::new(ReviewDiffTool {
        review: review.to_string(),
        simulate_failure,
        reads: reads.clone(),
    }));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        review: review.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.allowed_tools = vec!["review_diff".to_string()];
    options.max_steps = 3;
    options.policy = Some(Arc::new(Policy));
    options.require_policy = true;
    options.require_tool_scope = true;
    let result = Agent::new(options)?.run(
        &Session::new("code-review"),
        "Review the fixed diff and manifest, and draft comments only.",
    )?;
    Ok((result.output, reads.load(Ordering::SeqCst)))
}

fn run_tests() -> Result<()> {
    let (output, reads) = run_case(REVIEW_ID, false)?;
    let report: Value = serde_json::from_str(&output)
        .map_err(|error| PraxoError::new("INVALID_REPORT", error.to_string()))?;
    if reads != 1
        || report["review"]["findings"] != json!(2)
        || report["review"]["license_issue"] != json!(true)
        || report["review"]["status"] != json!("draft_only")
        || report["comments_posted"] != json!(0)
        || report["writes"] != json!(0)
    {
        return Err(PraxoError::new("SUCCESS_FAILED", output));
    }
    println!("success: review-100 findings=2 status=draft_only comments=0 reads=1");

    match run_case("review-200", false) {
        Err(error) if error.code == "AGENT_POLICY_DENIED" => {}
        _ => return Err(PraxoError::new("DENY_FAILED", "expected policy denial")),
    }
    println!("deny: AGENT_POLICY_DENIED reads=0");

    match run_case(REVIEW_ID, true) {
        Err(error) if error.code == "DIFF_UNAVAILABLE" => {}
        _ => return Err(PraxoError::new("FAILURE_FAILED", "expected source failure")),
    }
    println!("failure: DIFF_UNAVAILABLE reads=1");
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
    let index = args.iter().position(|arg| arg == "--review");
    let review = index
        .and_then(|position| args.get(position + 1))
        .map(String::as_str)
        .unwrap_or(REVIEW_ID);
    match run_case(review, args.iter().any(|arg| arg == "--simulate-failure")) {
        Ok((output, reads)) => println!("{output}\nreads={reads}"),
        Err(error) => {
            eprintln!("{error}");
            process::exit(if error.code == "AGENT_POLICY_DENIED" { 2 } else { 1 });
        }
    }
}
