use std::sync::{Arc, Mutex};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::event::{Event, Sink};
use praxo_core::hitl::{Interrupt, InterruptAction, InterruptDecision};
use praxo_core::model::{Message, Model, Request, Response, ToolCall, Usage};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{FuncTool, Registry};
use serde_json::{json, Map, Value};

struct ScriptedModel {
    responses: Mutex<Vec<Response>>,
}

impl ScriptedModel {
    fn new(responses: Vec<Response>) -> Self {
        Self {
            responses: Mutex::new(responses),
        }
    }
}

impl Model for ScriptedModel {
    fn generate(&self, _request: &Request) -> praxo_core::errors::Result<Response> {
        Ok(self.responses.lock().expect("script").remove(0))
    }
}

struct RespondModel {
    calls: Mutex<usize>,
}

impl Model for RespondModel {
    fn generate(&self, request: &Request) -> praxo_core::errors::Result<Response> {
        let mut calls = self.calls.lock().expect("calls");
        *calls += 1;
        if *calls == 1 {
            return Ok(tool_response());
        }
        let content = request
            .messages
            .iter()
            .rev()
            .find(|message| message.role == "tool")
            .and_then(|message| message.content.clone())
            .unwrap_or_else(|| "final".to_string());
        Ok(final_response(&content))
    }
}

struct RecordingSink {
    events: Mutex<Vec<Event>>,
}

impl Sink for RecordingSink {
    fn emit(&self, event: &Event) -> praxo_core::errors::Result<()> {
        self.events.lock().expect("sink").push(event.clone());
        Ok(())
    }
}

struct RecordingHook {
    actions: Mutex<Vec<(String, String)>>,
}

impl Hook for RecordingHook {
    fn authorize(&self, action: &Action) -> praxo_core::errors::Result<Decision> {
        if action.kind == "tool.invoke" {
            let value = action
                .arguments
                .as_ref()
                .and_then(|args| args.get("value"))
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            self.actions
                .lock()
                .expect("actions")
                .push((action.tool_name.clone().unwrap_or_default(), value));
        }
        Ok(Decision::allow(""))
    }
}

fn tool_response() -> Response {
    Response {
        message: Message::assistant(
            "",
            vec![ToolCall {
                id: "call-1".to_string(),
                name: "echo".to_string(),
                arguments: Map::from_iter([("value".to_string(), json!("original"))]),
            }],
        ),
        usage: Usage::default(),
        finish_reason: None,
    }
}

fn final_response(content: &str) -> Response {
    Response {
        message: Message::assistant(content, Vec::new()),
        usage: Usage::default(),
        finish_reason: None,
    }
}

fn registry(invoked: Arc<Mutex<Vec<Map<String, Value>>>>) -> Registry {
    let mut registry = Registry::new();
    registry.register(Arc::new(FuncTool::new("echo", "Echo", move |args| {
        invoked.lock().expect("invoked").push(args.clone());
        Ok(Value::Object(args.clone()))
    })));
    registry
}

fn build(
    decision: Option<praxo_core::hitl::InterruptHandler>,
    approval: Option<praxo_core::hitl::InterruptApproval>,
    extra: impl FnOnce(&mut AgentOptions),
) -> (Agent, Arc<Mutex<Vec<Map<String, Value>>>>) {
    let invoked = Arc::new(Mutex::new(Vec::new()));
    let mut options = AgentOptions::new(Arc::new(ScriptedModel::new(vec![
        tool_response(),
        final_response("final"),
    ])));
    options.tools = Some(Arc::new(registry(invoked.clone())));
    options.interrupt_on = vec!["echo".to_string()];
    options.on_interrupt_decision = decision;
    options.on_interrupt = approval;
    extra(&mut options);
    (Agent::new(options).expect("agent"), invoked)
}

#[test]
fn approve_runs_tool_with_original_arguments() {
    let handler: praxo_core::hitl::InterruptHandler =
        Arc::new(|_interrupt: &Interrupt| Ok(InterruptDecision::approve()));
    let (agent, invoked) = build(Some(handler), None, |_| {});
    let result = agent.run(&Session::new("s1"), "go").expect("run");
    assert_eq!(result.output, "final");
    assert_eq!(
        invoked.lock().expect("invoked").as_slice(),
        &[Map::from_iter([("value".to_string(), json!("original"))])]
    );
}

#[test]
fn edit_replaces_arguments_and_reauthorizes() {
    let handler: praxo_core::hitl::InterruptHandler = Arc::new(|_interrupt: &Interrupt| {
        Ok(InterruptDecision {
            action: InterruptAction::Edit,
            arguments: Some(Map::from_iter([("value".to_string(), json!("edited"))])),
            response: String::new(),
            reason: String::new(),
        })
    });
    let hook = Arc::new(RecordingHook {
        actions: Mutex::new(Vec::new()),
    });
    let (agent, invoked) = build(Some(handler), None, {
        let hook = hook.clone();
        move |options| options.policy = Some(hook)
    });
    let result = agent.run(&Session::new("s1"), "go").expect("run");
    assert_eq!(result.output, "final");
    assert_eq!(
        invoked.lock().expect("invoked").as_slice(),
        &[Map::from_iter([("value".to_string(), json!("edited"))])]
    );
    assert_eq!(
        hook.actions.lock().expect("actions").as_slice(),
        &[
            ("echo".to_string(), "original".to_string()),
            ("echo".to_string(), "edited".to_string()),
        ]
    );
}

#[test]
fn reject_fails_without_effects() {
    let handler: praxo_core::hitl::InterruptHandler = Arc::new(|_interrupt: &Interrupt| {
        Ok(InterruptDecision {
            action: InterruptAction::Reject,
            arguments: None,
            response: String::new(),
            reason: "not allowed".to_string(),
        })
    });
    let (agent, invoked) = build(Some(handler), None, |_| {});
    let error = agent
        .run(&Session::new("s1"), "go")
        .expect_err("reject");
    assert_eq!(error.code, "AGENT_APPROVAL_DENIED");
    assert!(invoked.lock().expect("invoked").is_empty());
}

#[test]
fn respond_skips_tool() {
    let handler: praxo_core::hitl::InterruptHandler = Arc::new(|_interrupt: &Interrupt| {
        Ok(InterruptDecision {
            action: InterruptAction::Respond,
            arguments: None,
            response: "human answer".to_string(),
            reason: String::new(),
        })
    });
    let invoked = Arc::new(Mutex::new(Vec::new()));
    let mut options = AgentOptions::new(Arc::new(RespondModel {
        calls: Mutex::new(0),
    }));
    options.tools = Some(Arc::new(registry(invoked.clone())));
    options.interrupt_on = vec!["echo".to_string()];
    options.on_interrupt_decision = Some(handler);
    let agent = Agent::new(options).expect("agent");
    let result = agent.run(&Session::new("s1"), "go").expect("run");
    assert_eq!(result.output, "\"human answer\"");
    assert!(invoked.lock().expect("invoked").is_empty());
}

#[test]
fn invalid_decision_fails() {
    let handler: praxo_core::hitl::InterruptHandler = Arc::new(|_interrupt: &Interrupt| {
        Ok(InterruptDecision {
            action: InterruptAction::Edit,
            arguments: None,
            response: String::new(),
            reason: String::new(),
        })
    });
    let (agent, invoked) = build(Some(handler), None, |_| {});
    let error = agent
        .run(&Session::new("s1"), "go")
        .expect_err("edit without args");
    assert_eq!(error.code, "AGENT_INTERRUPT_DECISION_INVALID");
    assert!(invoked.lock().expect("invoked").is_empty());
}

#[test]
fn unhandled_interrupt_fails() {
    let (agent, invoked) = build(None, None, |_| {});
    let error = agent
        .run(&Session::new("s1"), "go")
        .expect_err("unhandled");
    assert_eq!(error.code, "AGENT_INTERRUPT_UNHANDLED");
    assert!(invoked.lock().expect("invoked").is_empty());
}

#[test]
fn boolean_approval_can_deny() {
    let approval: praxo_core::hitl::InterruptApproval = Arc::new(|_interrupt: &Interrupt| Ok(false));
    let (agent, invoked) = build(None, Some(approval), |_| {});
    let error = agent.run(&Session::new("s1"), "go").expect_err("denied");
    assert_eq!(error.code, "AGENT_APPROVAL_DENIED");
    assert!(invoked.lock().expect("invoked").is_empty());
}

#[test]
fn emits_interrupt_event() {
    let sink = Arc::new(RecordingSink {
        events: Mutex::new(Vec::new()),
    });
    let handler: praxo_core::hitl::InterruptHandler =
        Arc::new(|_interrupt: &Interrupt| Ok(InterruptDecision::approve()));
    let (agent, _) = build(Some(handler), None, {
        let sink = sink.clone();
        move |options| options.events = Some(sink)
    });
    agent.run(&Session::new("s1"), "go").expect("run");
    let events = sink.events.lock().expect("sink");
    let interrupts: Vec<&Event> = events
        .iter()
        .filter(|event| event.kind == "tool.interrupt")
        .collect();
    assert_eq!(interrupts.len(), 1);
    let data = interrupts[0].data.as_ref().expect("data");
    assert_eq!(data.get("name"), Some(&json!("echo")));
    assert_eq!(
        data.get("arguments"),
        Some(&json!({"value": "original"}))
    );
}
