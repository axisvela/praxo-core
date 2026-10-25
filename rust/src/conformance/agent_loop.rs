use std::sync::{Arc, Mutex};

use serde_json::Value;

use crate::agent::{Agent, AgentOptions, RunResult, Session};
use crate::errors::PraxoError;
use crate::event::{Event, Sink};
use crate::model::{Message, Model, Request, Response, ToolCall, Usage};
use crate::tool::{Registry, Tool};

pub fn run_agent_loop(vector: &Value) -> std::result::Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    let steps = input["script"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let calls = Arc::new(Mutex::new(0usize));
    let mut registry = Registry::new();
    if let Some(tools) = input["tools"].as_array() {
        for tool in tools {
            registry.register(Arc::new(EchoTool {
                name: tool["name"].as_str().unwrap_or("").to_string(),
                description: tool["description"].as_str().unwrap_or("").to_string(),
                calls: calls.clone(),
            }));
        }
    }
    let sink = Arc::new(RecordingSink::default());
    let mut options = AgentOptions::new(Arc::new(ScriptedModel::new(steps)));
    options.tools = Some(Arc::new(registry));
    options.events = Some(sink.clone());
    options.max_steps = input["maxSteps"].as_u64().unwrap_or(0) as usize;
    options.max_tokens = input["maxTokens"].as_i64().unwrap_or(0);
    let agent = Agent::new(options).map_err(|error| error.message)?;
    let result: std::result::Result<RunResult, PraxoError> =
        agent.run(&Session::new("s1"), input["prompt"].as_str().unwrap_or(""));
    match result {
        Ok(result) => {
            check(
                expect["error"].as_bool().unwrap_or(false) == false,
                "unexpected success".to_string(),
            )?;
            check(
                Value::String(result.output.clone()) == expect["output"],
                format!("output: got {}", result.output),
            )?;
            check(
                result.steps as u64 == expect["steps"].as_u64().unwrap_or(0),
                format!("steps: got {}", result.steps),
            )?;
        }
        Err(error) => {
            check(
                expect["error"].as_bool().unwrap_or(false),
                error.message.clone(),
            )?;
            if let Some(code) = expect["errorCode"].as_str() {
                check(error.code == code, format!("errorCode: got {}", error.code))?;
            }
        }
    }
    let invocations = *calls.lock().expect("tool counter");
    check(
        invocations as u64 == expect["toolInvocations"].as_u64().unwrap_or(0),
        format!("tool invocations: got {invocations}"),
    )?;
    let events = sink.types.lock().expect("sink").clone();
    check(
        normalize(events) == expect["events"],
        "events mismatch".to_string(),
    )
}

struct ScriptedModel {
    steps: Vec<Value>,
    next: Mutex<usize>,
}

impl ScriptedModel {
    fn new(steps: Vec<Value>) -> Self {
        Self {
            steps,
            next: Mutex::new(0),
        }
    }
}

impl Model for ScriptedModel {
    fn generate(&self, _request: &Request) -> crate::errors::Result<Response> {
        let mut next = self.next.lock().expect("script");
        if *next >= self.steps.len() {
            return Err(PraxoError::new("SCRIPT", "script exhausted"));
        }
        let step = self.steps[*next].clone();
        *next += 1;
        let tool_calls: Vec<ToolCall> = step["toolCalls"]
            .as_array()
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .map(|call| serde_json::from_value(call).expect("tool call"))
            .collect();
        Ok(Response {
            message: Message::assistant(
                step["content"].as_str().unwrap_or(""),
                tool_calls,
            ),
            usage: Usage {
                input_tokens: step["inputTokens"].as_i64().unwrap_or(0),
                output_tokens: step["outputTokens"].as_i64().unwrap_or(0),
                cached_tokens: 0,
            },
            finish_reason: None,
        })
    }
}

struct EchoTool {
    name: String,
    description: String,
    calls: Arc<Mutex<usize>>,
}

impl Tool for EchoTool {
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> &str {
        &self.description
    }

    fn invoke(&self, args: &serde_json::Map<String, Value>) -> crate::errors::Result<Value> {
        *self.calls.lock().expect("tool counter") += 1;
        Ok(Value::Object(args.clone()))
    }
}

#[derive(Default)]
struct RecordingSink {
    types: Mutex<Vec<Value>>,
}

impl Sink for RecordingSink {
    fn emit(&self, event: &Event) -> crate::errors::Result<()> {
        self.types
            .lock()
            .expect("sink")
            .push(Value::String(event.kind.clone()));
        Ok(())
    }
}

fn normalize(values: Vec<Value>) -> Value {
    if values.is_empty() {
        Value::Null
    } else {
        Value::Array(values)
    }
}

fn check(condition: bool, detail: String) -> std::result::Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(detail)
    }
}
