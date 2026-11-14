use serde_json::json;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::checkpoint::Allowlist;
use praxo_core::errors::{PraxoError, Result};
use praxo_core::model::{
    Message, Model, Request, Response, ROLE_ASSISTANT, ROLE_USER,
};

struct TurnModel;

impl Model for TurnModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        Ok(Response {
            message: Message::assistant(
                format!("turn {}", request.messages.len()),
                Vec::new(),
            ),
            ..Response::default()
        })
    }
}

fn save(allowlist: &Allowlist, session: &Session) -> Result<String> {
    allowlist.marshal(
        "session",
        json!({"messages": session.messages}),
    )
}

fn restore(allowlist: &Allowlist, payload: &str) -> Result<Vec<Message>> {
    let value = allowlist.unmarshal(payload)?;
    serde_json::from_value(value["messages"].clone()).map_err(|error| {
        PraxoError::checkpoint(format!("session-checkpoint: {error}"))
    })
}

fn main() -> Result<()> {
    let allowlist = Allowlist::new();
    allowlist.register("session", || json!({"messages": []}))?;
    let mut session = Session::new("session-1");
    session.messages = vec![
        Message::text(ROLE_USER, "first"),
        Message::text(ROLE_ASSISTANT, "ack"),
    ];
    let mut payload = save(&allowlist, &session)?;

    let agent = Agent::new(AgentOptions::new(std::sync::Arc::new(TurnModel)))?;

    session.messages = restore(&allowlist, &payload)?;
    let result = agent.run(&session, "second")?;
    assert_eq!(result.output, "turn 3");

    session.messages.push(Message::text(ROLE_USER, "second"));
    session
        .messages
        .push(Message::text(ROLE_ASSISTANT, result.output.clone()));
    payload = save(&allowlist, &session)?;

    session.messages = restore(&allowlist, &payload)?;
    let result = agent.run(&session, "third")?;
    assert_eq!(result.output, "turn 5");

    println!("restored messages: {}", session.messages.len());
    println!("output: {}", result.output);
    Ok(())
}
