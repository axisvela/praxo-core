use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::model::{Message, Model, Request, Response, ToolCall, ROLE_TOOL};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{FuncTool, Registry};
use serde_json::{Map, Value};

const SESSION_ID: &str = "session-1";

#[derive(Clone)]
struct Principal {
    tenant: String,
    role: String,
    active: bool,
}

struct IdentityPolicy {
    principal: Option<Principal>,
}

impl Hook for IdentityPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        let Some(principal) = &self.principal else {
            return Ok(Decision::deny("trusted principal is missing"));
        };
        if !principal.active {
            return Ok(Decision::deny("trusted principal is inactive"));
        }
        if action.kind == "model.generate" {
            return Ok(Decision::allow("principal may run the agent"));
        }
        if action.kind != "tool.invoke" {
            return Ok(Decision::deny("unsupported action"));
        }
        if principal.role != "operator" {
            return Ok(Decision::deny("role is not permitted"));
        }
        let claimed_tenant = action
            .arguments
            .as_ref()
            .and_then(|arguments| arguments.get("tenant"))
            .and_then(Value::as_str);
        if claimed_tenant != Some(principal.tenant.as_str()) {
            return Ok(Decision::deny("tenant does not match the principal"));
        }
        if action.tool_name.as_deref() != Some("record") {
            return Ok(Decision::deny("operation is not permitted"));
        }
        Ok(Decision::allow("verified operator"))
    }
}

struct ClaimingModel {
    tenant: String,
    role: String,
}

impl Model for ClaimingModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        if request
            .messages
            .last()
            .map(|message| message.role == ROLE_TOOL)
            .unwrap_or(false)
        {
            return Ok(Response {
                message: Message::assistant("recorded", Vec::new()),
                ..Response::default()
            });
        }
        let mut arguments = Map::new();
        arguments.insert("tenant".to_string(), Value::String(self.tenant.clone()));
        arguments.insert("role".to_string(), Value::String(self.role.clone()));
        Ok(Response {
            message: Message::assistant(
                "",
                vec![ToolCall {
                    id: "record-1".to_string(),
                    name: "record".to_string(),
                    arguments,
                }],
            ),
            ..Response::default()
        })
    }
}

fn run_case(
    principal: Option<Principal>,
    claimed_tenant: &str,
    claimed_role: &str,
) -> (usize, Option<PraxoError>) {
    let calls = Arc::new(AtomicUsize::new(0));
    let recorded = calls.clone();
    let mut tools = Registry::new();
    tools.register(Arc::new(FuncTool::new(
        "record",
        "Record a target.",
        move |_args| {
            recorded.fetch_add(1, Ordering::SeqCst);
            Ok(Value::String("recorded".to_string()))
        },
    )));
    let mut options = AgentOptions::new(Arc::new(ClaimingModel {
        tenant: claimed_tenant.to_string(),
        role: claimed_role.to_string(),
    }));
    options.tools = Some(Arc::new(tools));
    options.policy = Some(Arc::new(IdentityPolicy { principal }));
    options.allowed_tools = vec!["record".to_string()];
    options.max_steps = 3;
    let agent = Agent::new(options).expect("agent");
    let outcome = agent.run(&Session::new(SESSION_ID), "record");
    let result = match outcome {
        Ok(result) if result.output == "recorded" => (calls.load(Ordering::SeqCst), None),
        Ok(result) => (
            calls.load(Ordering::SeqCst),
            Some(PraxoError::new("TEST", result.output)),
        ),
        Err(error) => (calls.load(Ordering::SeqCst), Some(error)),
    };
    result
}

fn main() {
    let cases = [
        ("missing", None, "acme", "admin", false),
        (
            "inactive",
            Some(Principal {
                tenant: "acme".to_string(),
                role: "operator".to_string(),
                active: false,
            }),
            "acme",
            "admin",
            false,
        ),
        (
            "role",
            Some(Principal {
                tenant: "acme".to_string(),
                role: "viewer".to_string(),
                active: true,
            }),
            "acme",
            "admin",
            false,
        ),
        (
            "tenant",
            Some(Principal {
                tenant: "acme".to_string(),
                role: "operator".to_string(),
                active: true,
            }),
            "other",
            "admin",
            false,
        ),
        (
            "operator",
            Some(Principal {
                tenant: "acme".to_string(),
                role: "operator".to_string(),
                active: true,
            }),
            "acme",
            "admin",
            true,
        ),
    ];

    for (name, principal, tenant, role, allowed) in cases {
        let (calls, error) = run_case(principal, tenant, role);
        if allowed {
            assert!(error.is_none(), "{name}: unexpected error");
            assert_eq!(calls, 1, "{name}: expected one effect");
        } else {
            let error = error.expect("denied case");
            assert_eq!(error.code, "AGENT_POLICY_DENIED", "{name}");
            assert_eq!(calls, 0, "{name}: effect ran before denial");
        }
    }

    println!("identity policy test: ok");
}
