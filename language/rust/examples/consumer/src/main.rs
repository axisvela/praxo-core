use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

struct FixtureModel {
    target: String,
}

impl Model for FixtureModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        let last_is_tool = request
            .messages
            .last()
            .map(|message| message.role == "tool")
            .unwrap_or(false);
        if last_is_tool {
            return Ok(Response {
                message: Message::assistant("recorded", Vec::new()),
                ..Response::default()
            });
        }
        let mut arguments = Map::new();
        arguments.insert("target".to_string(), json!(self.target));
        Ok(Response {
            message: Message {
                role: "assistant".to_string(),
                content: Some(String::new()),
                content_blocks: Vec::new(),
                tool_calls: vec![ToolCall {
                    id: "record-1".to_string(),
                    name: "record".to_string(),
                    arguments,
                }],
                tool_id: None,
            },
            ..Response::default()
        })
    }
}

struct RecordTool {
    calls: Arc<AtomicUsize>,
}

impl Tool for RecordTool {
    fn name(&self) -> &str {
        "record"
    }

    fn description(&self) -> &str {
        "Record a target in an in-memory counter."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(json!("recorded"))
    }
}

struct PublicTargetPolicy;

impl Hook for PublicTargetPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("model generation")),
            "tool.invoke" => {
                let target = action
                    .arguments
                    .as_ref()
                    .and_then(|arguments| arguments.get("target"))
                    .and_then(|value| value.as_str());
                if action.tool_name.as_deref() == Some("record") && target == Some("public") {
                    Ok(Decision::allow("only the public target is permitted"))
                } else {
                    Ok(Decision::deny("only the public target is permitted"))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn run_scenario(target: &str) -> (Result<String>, usize) {
    let calls = Arc::new(AtomicUsize::new(0));
    let mut registry = Registry::new();
    registry.register(Arc::new(RecordTool {
        calls: calls.clone(),
    }));

    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        target: target.to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 3;
    options.allowed_tools = vec!["record".to_string()];
    options.policy = Some(Arc::new(PublicTargetPolicy));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(&Session::new(format!("consumer-{target}")), "Record the requested target.")
        .map(|result| result.output);
    (result, calls.load(Ordering::SeqCst))
}

fn main() {
    let (allowed, allowed_calls) = run_scenario("public");
    assert_eq!(allowed.expect("allow path"), "recorded");
    assert_eq!(allowed_calls, 1);
    println!("allow: recorded; effects=1");

    let (denied, denied_calls) = run_scenario("private");
    let error = denied.expect_err("private target must be denied");
    assert_eq!(error.code, "AGENT_POLICY_DENIED");
    assert_eq!(denied_calls, 0);
    println!("deny: policy rejected; effects=0");
}
