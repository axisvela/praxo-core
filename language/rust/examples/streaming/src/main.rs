use std::sync::Arc;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::model::{Message, Model, Request, Response, StreamingModel};

struct StreamingFake {
    chunks: Vec<String>,
}

impl StreamingFake {
    fn new(chunks: &[&str]) -> Self {
        Self {
            chunks: chunks.iter().map(|chunk| chunk.to_string()).collect(),
        }
    }
}

impl Model for StreamingFake {
    fn generate(&self, _request: &Request) -> Result<Response> {
        Ok(Response {
            message: Message::assistant(self.chunks.concat(), Vec::new()),
            ..Response::default()
        })
    }
}

impl StreamingModel for StreamingFake {
    fn generate_stream(
        &self,
        request: &Request,
        on_delta: &mut dyn FnMut(&str) -> Result<()>,
    ) -> Result<Response> {
        for chunk in &self.chunks {
            on_delta(chunk)?;
        }
        self.generate(request)
    }
}

fn build_agent(chunks: &[&str]) -> Agent {
    let mut options = AgentOptions::new(Arc::new(StreamingFake::new(chunks)));
    options.streaming_model = Some(Arc::new(StreamingFake::new(chunks)));
    options.system_prompt = "Answer with the current status.".to_string();
    options.max_steps = 2;
    Agent::new(options).expect("agent")
}

fn main() {
    let chunks = ["status: ", "green"];
    let agent = build_agent(&chunks);
    let mut received = Vec::new();

    let result = agent
        .run_stream(
            &Session::new("streaming"),
            "Check the status.",
            &mut |delta| {
                received.push(delta.to_string());
                Ok(())
            },
        )
        .expect("run stream");

    assert_eq!(result.output, "status: green");
    assert_eq!(received, chunks);
    assert_eq!(received.concat(), result.output);

    println!("streaming test: ok");
}
