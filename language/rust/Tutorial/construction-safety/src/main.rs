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

const SITE_ID: &str = "site-100";

struct FixtureModel {
    site: String,
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
                "read_site",
                json!({ "site_id": self.site }),
            ));
        }
        if tools.len() == 1 {
            return Ok(Self::tool_response(
                "checklist-1",
                "draft_checklist",
                json!({
                    "site_id": self.site,
                    "action": "draft_remediation"
                }),
            ));
        }
        let site = Self::tool_payload(&tools, 0);
        let checklist = Self::tool_payload(&tools, 1);
        let report = json!({
            "site": site,
            "checklist": checklist,
            "policy": "read and draft only; certified findings and remediation remain application-owned",
            "certified_findings": 0,
            "writes": 0
        });
        Ok(Response {
            message: Message::assistant(report.to_string(), Vec::new()),
            ..Response::default()
        })
    }
}

trait SiteAdapter: Send + Sync {
    fn read(&self, site: &str) -> Result<Value>;
}

struct FixtureSite {
    simulate_failure: bool,
}

impl SiteAdapter for FixtureSite {
    fn read(&self, site: &str) -> Result<Value> {
        if self.simulate_failure {
            return Err(PraxoError::new(
                "SITE_SOURCE_UNAVAILABLE",
                "inspection adapter unavailable",
            ));
        }
        Ok(json!({
            "site_id": site,
            "inspection": "scaffold",
            "findings": [
                { "id": "missing-guardrail", "severity": "high" },
                { "id": "expired-harness-tag", "severity": "medium" }
            ],
            "photo_refs": 0,
            "source": "site_fixture"
        }))
    }
}

struct ReadSiteTool {
    adapter: Arc<dyn SiteAdapter>,
    reads: Arc<AtomicUsize>,
}

impl Tool for ReadSiteTool {
    fn name(&self) -> &str {
        "read_site"
    }

    fn description(&self) -> &str {
        "Read fixed construction inspection labels; no vision or field access."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.reads.fetch_add(1, Ordering::SeqCst);
        let site = args
            .get("site_id")
            .and_then(Value::as_str)
            .unwrap_or(SITE_ID);
        self.adapter.read(site)
    }
}

struct DraftChecklistTool;

impl Tool for DraftChecklistTool {
    fn name(&self) -> &str {
        "draft_checklist"
    }

    fn description(&self) -> &str {
        "Draft a review-only remediation checklist without a certified finding."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let site = args
            .get("site_id")
            .and_then(Value::as_str)
            .unwrap_or(SITE_ID);
        let action = args
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("draft_remediation");
        Ok(json!({
            "checklist_id": "safety-100",
            "site_id": site,
            "action": action,
            "items": ["replace-guardrail", "renew-harness-tag"],
            "status": "draft_only",
            "review_required": true,
            "certified_findings": 0,
            "writes": 0
        }))
    }
}

struct SafetyPolicy;

impl Hook for SafetyPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("deterministic safety checklist")),
            "tool.invoke" => {
                let site = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("site_id"))
                    .and_then(Value::as_str);
                let action_name = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("action"))
                    .and_then(Value::as_str);
                let allowed = match action.tool_name.as_deref() {
                    Some("read_site") => site == Some(SITE_ID),
                    Some("draft_checklist") => {
                        site == Some(SITE_ID) && action_name == Some("draft_remediation")
                    }
                    _ => false,
                };
                if allowed {
                    Ok(Decision::allow("site-100 read and draft review only"))
                } else {
                    Ok(Decision::deny(
                        "only site-100 read and draft remediation are allowed",
                    ))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn review(site: &str, simulate_failure: bool) -> (Result<String>, usize) {
    let reads = Arc::new(AtomicUsize::new(0));
    let adapter = Arc::new(FixtureSite { simulate_failure });
    let mut registry = Registry::new();
    registry.register(Arc::new(ReadSiteTool {
        adapter,
        reads: reads.clone(),
    }));
    registry.register(Arc::new(DraftChecklistTool));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        site: site.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 5;
    options.allowed_tools = vec!["read_site".to_string(), "draft_checklist".to_string()];
    options.policy = Some(Arc::new(SafetyPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(
            &Session::new(format!("construction-safety-{site}")),
            "Inspect the fixed site labels and draft a review-only safety checklist.",
        )
        .map(|result| result.output);
    (result, reads.load(Ordering::SeqCst))
}

fn run_tests() {
    let (success, reads) = review(SITE_ID, false);
    let report: Value =
        serde_json::from_str(&success.expect("success path")).expect("success report must be JSON");
    assert_eq!(report["site"]["site_id"], SITE_ID);
    assert_eq!(report["site"]["inspection"], "scaffold");
    assert_eq!(report["site"]["findings"][0]["id"], "missing-guardrail");
    assert_eq!(report["checklist"]["status"], "draft_only");
    assert_eq!(report["checklist"]["review_required"], true);
    assert_eq!(report["checklist"]["items"][0], "replace-guardrail");
    assert_eq!(report["certified_findings"], 0);
    assert_eq!(reads, 1);
    println!("success: site-100 inspection=scaffold findings=2 status=draft_only certified=0 reads=1");

    let (denied, denied_reads) = review("site-200", false);
    let denied = denied.expect_err("out-of-scope site must be denied");
    assert_eq!(denied.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_reads, 0);
    println!("deny: {} reads=0", denied.code);

    let (failure, failure_reads) = review(SITE_ID, true);
    let failure = failure.expect_err("simulated adapter failure must fail");
    assert_eq!(failure.code, "SITE_SOURCE_UNAVAILABLE");
    assert_eq!(failure_reads, 1);
    println!("failure: {} reads=1", failure.code);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.iter().any(|arg| arg == "--test") {
        run_tests();
        return;
    }
    let site = args
        .windows(2)
        .find(|pair| pair[0] == "--site")
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| SITE_ID.to_string());
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match review(&site, simulate_failure) {
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
