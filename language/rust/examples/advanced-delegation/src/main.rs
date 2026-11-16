use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

struct FixtureModel {
    tool_name: String,
    arguments: Map<String, Value>,
    completion: String,
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
                message: Message::assistant(&self.completion, Vec::new()),
                ..Response::default()
            });
        }
        Ok(Response {
            message: Message {
                role: "assistant".to_string(),
                content: Some(String::new()),
                content_blocks: Vec::new(),
                tool_calls: vec![ToolCall {
                    id: "call-1".to_string(),
                    name: self.tool_name.clone(),
                    arguments: self.arguments.clone(),
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
        "Record a child result in an in-memory counter."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(json!("recorded:delegated"))
    }
}

struct ParentOnlyTool;

impl Tool for ParentOnlyTool {
    fn name(&self) -> &str {
        "parent_only"
    }

    fn description(&self) -> &str {
        "A tool that must remain outside the child scope."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        Ok(json!("parent-effect"))
    }
}

struct ChildPolicy;

impl Hook for ChildPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("child generation")),
            "tool.invoke" => {
                if action.tool_name.as_deref() == Some("record") {
                    Ok(Decision::allow("child may only record"))
                } else {
                    Ok(Decision::deny("child may only record"))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

struct ParentPolicy;

impl Hook for ParentPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("parent generation")),
            "tool.invoke" => {
                if matches!(
                    action.tool_name.as_deref(),
                    Some("delegate") | Some("parent_only")
                ) {
                    Ok(Decision::allow("parent may delegate but not record"))
                } else {
                    Ok(Decision::deny("parent may delegate but not record"))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn build_child(calls: Arc<AtomicUsize>) -> Result<Agent> {
    let mut registry = Registry::new();
    registry.register(Arc::new(RecordTool { calls }));
    let mut arguments = Map::new();
    arguments.insert("target".to_string(), json!("delegated"));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        tool_name: "record".to_string(),
        arguments,
        completion: "child-recorded".to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 3;
    options.allowed_tools = vec!["record".to_string()];
    options.policy = Some(Arc::new(ChildPolicy));
    Agent::new(options)
}

struct DelegateTool {
    calls: Arc<AtomicUsize>,
}

impl Tool for DelegateTool {
    fn name(&self) -> &str {
        "delegate"
    }

    fn description(&self) -> &str {
        "Run the child agent with a restricted tool scope."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let task = args
            .get("task")
            .and_then(Value::as_str)
            .unwrap_or("record the delegated result");
        let child = build_child(self.calls.clone())?;
        let result = child.run(&Session::new("advanced-delegation-child"), task)?;
        Ok(json!({
            "output": result.output,
            "effects": self.calls.load(Ordering::SeqCst),
        }))
    }
}

fn build_parent(calls: Arc<AtomicUsize>) -> Result<Agent> {
    let mut registry = Registry::new();
    registry.register(Arc::new(DelegateTool {
        calls: calls.clone(),
    }));
    registry.register(Arc::new(ParentOnlyTool));
    let mut arguments = Map::new();
    arguments.insert("task".to_string(), json!("record the delegated result"));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        tool_name: "delegate".to_string(),
        arguments,
        completion: "parent-done".to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 3;
    options.allowed_tools = vec!["delegate".to_string(), "parent_only".to_string()];
    options.policy = Some(Arc::new(ParentPolicy));
    Agent::new(options)
}

struct DirectPolicy;

impl Hook for DirectPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind == "model.generate" {
            Ok(Decision::allow("parent generation"))
        } else {
            Ok(Decision::deny("parent may not record"))
        }
    }
}

fn main() {
    let calls = Arc::new(AtomicUsize::new(0));
    let parent = build_parent(calls.clone()).expect("parent");
    let result = parent
        .run(
            &Session::new("advanced-delegation-parent"),
            "Delegate the record operation to the child agent.",
        )
        .expect("parent run");
    assert_eq!(result.output, "parent-done");
    assert_eq!(calls.load(Ordering::SeqCst), 1);
    println!("delegation: child recorded; parent scope enforced");

    let mut registry = Registry::new();
    registry.register(Arc::new(RecordTool {
        calls: calls.clone(),
    }));
    let mut arguments = Map::new();
    arguments.insert("target".to_string(), json!("parent"));
    let mut options = AgentOptions::new(Arc::new(FixtureModel {
        tool_name: "record".to_string(),
        arguments,
        completion: "unexpected".to_string(),
    }));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 3;
    options.allowed_tools = vec!["record".to_string()];
    options.policy = Some(Arc::new(DirectPolicy));
    let denied = Agent::new(options).expect("direct agent");
    let error = denied
        .run(
            &Session::new("advanced-delegation-direct"),
            "Record directly.",
        )
        .expect_err("parent record must be denied");
    assert_eq!(error.code, "AGENT_POLICY_DENIED");
    assert_eq!(calls.load(Ordering::SeqCst), 1);
    println!("deny: parent record blocked; child effect unchanged");
}
