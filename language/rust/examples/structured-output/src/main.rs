use std::sync::Arc;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::middleware::StructuredOutput;
use praxo_core::model::{Message, Model, Request, Response};
use serde_json::{json, Value};

struct FakeModel {
    content: &'static str,
}

impl Model for FakeModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        Ok(Response {
            message: Message::assistant(self.content, Vec::new()),
            ..Response::default()
        })
    }
}

fn schema() -> serde_json::Map<String, Value> {
    json!({
        "type": "object",
        "required": ["title", "summary", "tags"],
        "properties": {
            "title": {"type": "string"},
            "summary": {"type": "string"},
            "tags": {"type": "array", "items": {"type": "string"}},
        },
    })
    .as_object()
    .expect("schema object")
    .clone()
}

fn summarize(content: &'static str) -> Result<String> {
    let mut options = AgentOptions::new(Arc::new(FakeModel { content }));
    options.system_prompt =
        "Summarize the supplied text as JSON with title, summary, and tags. Return only JSON."
            .to_string();
    options.structured_output = Some(StructuredOutput::new(schema()).with_name("summary"));
    let result = Agent::new(options)?.run(
        &Session::new("structured-output"),
        "Quarterly status: all checks green.",
    )?;
    Ok(result.output)
}

fn main() {
    let output = summarize(
        r#"{"title":"Release status","summary":"All checks are green.","tags":["release","status"]}"#,
    )
    .expect("valid output");
    let data: Value = serde_json::from_str(&output).expect("json output");
    assert!(data.get("title").and_then(Value::as_str).is_some());
    assert!(data.get("summary").and_then(Value::as_str).is_some());
    assert!(data.get("tags").and_then(Value::as_array).is_some());

    let error = summarize(r#"{"title":"Release status"}"#).expect_err("invalid output");
    assert_eq!(error.code, "AGENT_STRUCTURED_OUTPUT");

    println!("structured output test: ok");
}
