use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::event::{Event, FilterSink, MultiSink, Sink};
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::tool::{FuncTool, Registry};
use serde_json::{Map, Value};

#[derive(Default)]
struct RecordingSink {
    events: Mutex<Vec<Event>>,
}

impl RecordingSink {
    fn types(&self) -> Vec<String> {
        self.events
            .lock()
            .expect("events")
            .iter()
            .map(|event| event.kind.clone())
            .collect()
    }

    fn events(&self) -> Vec<Event> {
        self.events.lock().expect("events").clone()
    }
}

impl Sink for RecordingSink {
    fn emit(&self, event: &Event) -> Result<()> {
        self.events.lock().expect("events").push(event.clone());
        Ok(())
    }
}

struct ToolThenAnswerModel {
    calls: AtomicUsize,
}

impl Model for ToolThenAnswerModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        let call = self.calls.fetch_add(1, Ordering::SeqCst);
        if call == 0 {
            let mut arguments = Map::new();
            arguments.insert("key".to_string(), Value::String("status".to_string()));
            return Ok(Response {
                message: Message::assistant(
                    "",
                    vec![ToolCall {
                        id: "call-1".to_string(),
                        name: "lookup".to_string(),
                        arguments,
                    }],
                ),
                ..Response::default()
            });
        }
        Ok(Response {
            message: Message::assistant("status: green", Vec::new()),
            ..Response::default()
        })
    }
}

fn build_agent(all_sink: Arc<RecordingSink>, tool_sink: Arc<RecordingSink>) -> Agent {
    let mut tools = Registry::new();
    tools.register(Arc::new(FuncTool::new(
        "lookup",
        "Look up a small status value.",
        |_args| Ok(Value::String("green".to_string())),
    )));

    let filtered = FilterSink::new(tool_sink as Arc<dyn Sink>, |event| {
        event.kind == "tool.call"
    });
    let events = MultiSink::new(vec![
        all_sink as Arc<dyn Sink>,
        Arc::new(filtered) as Arc<dyn Sink>,
    ]);

    let mut options = AgentOptions::new(Arc::new(ToolThenAnswerModel {
        calls: AtomicUsize::new(0),
    }));
    options.tools = Some(Arc::new(tools));
    options.events = Some(Arc::new(events));
    options.system_prompt = "Use tools when asked for status.".to_string();
    options.max_steps = 3;
    Agent::new(options).expect("agent")
}

fn main() {
    let all_sink = Arc::new(RecordingSink::default());
    let tool_sink = Arc::new(RecordingSink::default());
    let agent = build_agent(all_sink.clone(), tool_sink.clone());

    let result = agent
        .run(&Session::new("event-sink"), "Check the status.")
        .expect("run");
    assert_eq!(result.output, "status: green");
    assert_eq!(
        all_sink.types(),
        vec!["run.started", "tool.call", "run.completed"]
    );
    assert_eq!(tool_sink.types(), vec!["tool.call"]);

    let events = tool_sink.events();
    let data = events[0].data.as_ref().expect("tool data");
    assert_eq!(data.get("name"), Some(&Value::String("lookup".to_string())));

    println!("event sink test: ok");
}
