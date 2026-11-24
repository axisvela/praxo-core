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

const PORTFOLIO_ID: &str = "portfolio-100";

struct FixtureModel {
    portfolio: String,
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
                "risk-1",
                "check_risk",
                json!({ "portfolio_id": self.portfolio, "action": "draft_order" }),
            ));
        }
        let risk = Self::payload(&tools, 0);
        let report = json!({
            "stage": "risk_order_drafted",
            "risk": risk,
            "trades": 0,
            "writes": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

struct CheckRiskTool {
    portfolio: String,
    simulate_failure: bool,
    reads: Arc<AtomicUsize>,
}

impl Tool for CheckRiskTool {
    fn name(&self) -> &str {
        "check_risk"
    }

    fn description(&self) -> &str {
        "Replay fixed prices and enforce deterministic exposure limits."
    }

    fn invoke(&self, _arguments: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        if self.simulate_failure {
            return Err(PraxoError::new(
                "PRICE_DATA_UNAVAILABLE",
                "synthetic price series unavailable",
            ));
        }
        Ok(json!({
            "portfolio_id": self.portfolio,
            "positions": 2,
            "exposure": 120,
            "limit": 100,
            "exceeded": true,
            "order_id": "order-100",
            "order_side": "reduce",
            "status": "draft_only",
            "review_required": true,
            "trades": 0,
            "source": "price_fixture"
        }))
    }
}

struct Policy;

impl Hook for Policy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind == "model.generate" {
            return Ok(Decision::allow("deterministic risk check"));
        }
        if action.kind != "tool.invoke" {
            return Ok(Decision::deny("unsupported action"));
        }
        let arguments = action.arguments.as_ref();
        let portfolio = arguments
            .and_then(|values| values.get("portfolio_id"))
            .and_then(Value::as_str)
            .unwrap_or("");
        let draft = arguments
            .and_then(|values| values.get("action"))
            .and_then(Value::as_str)
            .unwrap_or("");
        if portfolio != PORTFOLIO_ID {
            return Ok(Decision::deny("only portfolio-100 is in scope"));
        }
        if action.tool_name.as_deref() == Some("check_risk") && draft == "draft_order" {
            return Ok(Decision::allow("portfolio-100 draft order only"));
        }
        Ok(Decision::deny("only a review-only order draft is allowed"))
    }
}

fn run_case(portfolio: &str, simulate_failure: bool) -> Result<(String, usize)> {
    let reads = Arc::new(AtomicUsize::new(0));
    let mut registry = Registry::new();
    registry.register(Arc::new(CheckRiskTool {
        portfolio: portfolio.to_string(),
        simulate_failure,
        reads: reads.clone(),
    }));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        portfolio: portfolio.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.allowed_tools = vec!["check_risk".to_string()];
    options.max_steps = 3;
    options.policy = Some(Arc::new(Policy));
    options.require_policy = true;
    options.require_tool_scope = true;
    let result = Agent::new(options)?.run(
        &Session::new("quant-risk"),
        "Replay fixed prices, check exposure and draft a review-only order.",
    )?;
    Ok((result.output, reads.load(Ordering::SeqCst)))
}

fn run_tests() -> Result<()> {
    let (output, reads) = run_case(PORTFOLIO_ID, false)?;
    let report: Value = serde_json::from_str(&output)
        .map_err(|error| PraxoError::new("INVALID_REPORT", error.to_string()))?;
    if reads != 1
        || report["risk"]["exposure"] != json!(120)
        || report["risk"]["limit"] != json!(100)
        || report["risk"]["exceeded"] != json!(true)
        || report["risk"]["status"] != json!("draft_only")
        || report["trades"] != json!(0)
        || report["writes"] != json!(0)
    {
        return Err(PraxoError::new("SUCCESS_FAILED", output));
    }
    println!("success: portfolio-100 exposure=120 limit=100 status=draft_only trades=0 reads=1");

    match run_case("portfolio-200", false) {
        Err(error) if error.code == "AGENT_POLICY_DENIED" => {}
        _ => return Err(PraxoError::new("DENY_FAILED", "expected policy denial")),
    }
    println!("deny: AGENT_POLICY_DENIED reads=0");

    match run_case(PORTFOLIO_ID, true) {
        Err(error) if error.code == "PRICE_DATA_UNAVAILABLE" => {}
        _ => return Err(PraxoError::new("FAILURE_FAILED", "expected source failure")),
    }
    println!("failure: PRICE_DATA_UNAVAILABLE reads=1");
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
    let index = args.iter().position(|arg| arg == "--portfolio");
    let portfolio = index
        .and_then(|position| args.get(position + 1))
        .map(String::as_str)
        .unwrap_or(PORTFOLIO_ID);
    match run_case(portfolio, args.iter().any(|arg| arg == "--simulate-failure")) {
        Ok((output, reads)) => println!("{output}\nreads={reads}"),
        Err(error) => {
            eprintln!("{error}");
            process::exit(if error.code == "AGENT_POLICY_DENIED" { 2 } else { 1 });
        }
    }
}
