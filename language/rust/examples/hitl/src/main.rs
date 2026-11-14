use std::sync::{Arc, Mutex};

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::hitl::{InterruptAction, InterruptDecision};
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

struct FixtureModel;

impl Model for FixtureModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        let last_is_tool = request
            .messages
            .last()
            .map(|message| message.role == "tool")
            .unwrap_or(false);
        if last_is_tool {
            return Ok(Response {
                message: Message::assistant("done", Vec::new()),
                ..Response::default()
            });
        }
        let mut arguments = Map::new();
        arguments.insert("text".to_string(), json!("hello"));
        arguments.insert("visibility".to_string(), json!("public"));
        Ok(Response {
            message: Message {
                role: "assistant".to_string(),
                content: Some(String::new()),
                content_blocks: Vec::new(),
                tool_calls: vec![ToolCall {
                    id: "write-note-1".to_string(),
                    name: "write_note".to_string(),
                    arguments,
                }],
                tool_id: None,
            },
            ..Response::default()
        })
    }
}

struct WriteNoteTool {
    notes: Arc<Mutex<Vec<String>>>,
}

impl Tool for WriteNoteTool {
    fn name(&self) -> &str {
        "write_note"
    }

    fn description(&self) -> &str {
        "Write a short note with the requested visibility."
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        let text = args
            .get("text")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        self.notes.lock().unwrap().push(text);
        Ok(json!("written"))
    }
}

struct PublicNotesPolicy;

impl Hook for PublicNotesPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind == "model.generate" {
            return Ok(Decision::allow("model generation"));
        }
        if action.kind == "tool.invoke" {
            let visibility = action
                .arguments
                .as_ref()
                .and_then(|arguments| arguments.get("visibility"))
                .and_then(Value::as_str);
            return Ok(if action.tool_name.as_deref() == Some("write_note")
                && visibility == Some("public")
            {
                Decision::allow("only public notes are permitted")
            } else {
                Decision::deny("only public notes are permitted")
            });
        }
        Ok(Decision::deny("unsupported action"))
    }
}

fn run_scenario(decision: InterruptDecision) -> (Result<String>, usize) {
    let notes = Arc::new(Mutex::new(Vec::new()));
    let mut registry = Registry::new();
    registry.register(Arc::new(WriteNoteTool {
        notes: notes.clone(),
    }));

    let mut options = AgentOptions::new(Arc::new(FixtureModel));
    options.tools = Some(Arc::new(registry));
    options.max_steps = 3;
    options.allowed_tools = vec!["write_note".to_string()];
    options.policy = Some(Arc::new(PublicNotesPolicy));
    options.interrupt_on = vec!["write_note".to_string()];
    let fixed = decision.clone();
    options.on_interrupt_decision =
        Some(Arc::new(move |_interrupt| Ok(fixed.clone())));

    let agent = Agent::new(options).expect("agent");
    let result = agent
        .run(&Session::new("hitl"), "Write a note.")
        .map(|result| result.output);
    let count = notes.lock().unwrap().len();
    (result, count)
}

fn main() {
    let (approved, approved_count) = run_scenario(InterruptDecision::approve());
    assert_eq!(approved.expect("approve"), "done");
    assert_eq!(approved_count, 1);
    println!("approve: written; effects=1");

    let (edited, edited_count) = run_scenario(InterruptDecision {
        action: InterruptAction::Edit,
        arguments: Some(Map::from_iter([
            ("text".to_string(), json!("hello")),
            ("visibility".to_string(), json!("private")),
        ])),
        response: String::new(),
        reason: String::new(),
    });
    let error = edited.expect_err("private note must be denied");
    assert_eq!(error.code, "AGENT_POLICY_DENIED");
    assert_eq!(edited_count, 0);
    println!("edit: policy rejected; effects=0");
}
