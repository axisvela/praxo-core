use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::model::{Message, Model, Request, Response};

struct FakeModel {
    content: &'static str,
    calls: Arc<AtomicUsize>,
    fail: bool,
}

impl Model for FakeModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        if self.fail {
            return Err(PraxoError::new("MODEL_UNAVAILABLE", "primary unavailable"));
        }
        Ok(Response {
            message: Message::assistant(self.content, Vec::new()),
            ..Response::default()
        })
    }
}

fn build_agent(
    primary_content: &'static str,
    primary_fail: bool,
    fallback_content: &'static str,
    fallback_fail: bool,
) -> (Agent, Arc<AtomicUsize>, Arc<AtomicUsize>) {
    let primary_calls = Arc::new(AtomicUsize::new(0));
    let fallback_calls = Arc::new(AtomicUsize::new(0));
    let primary = Arc::new(FakeModel {
        content: primary_content,
        calls: primary_calls.clone(),
        fail: primary_fail,
    });
    let fallback = Arc::new(FakeModel {
        content: fallback_content,
        calls: fallback_calls.clone(),
        fail: fallback_fail,
    });
    let mut options = AgentOptions::new(primary);
    options.fallback_model = Some(fallback);
    (
        Agent::new(options).expect("agent"),
        primary_calls,
        fallback_calls,
    )
}

fn run_prompt(
    primary_content: &'static str,
    primary_fail: bool,
    fallback_content: &'static str,
    fallback_fail: bool,
    prompt: &str,
) -> (Result<String>, usize, usize) {
    let (agent, primary_calls, fallback_calls) = build_agent(
        primary_content,
        primary_fail,
        fallback_content,
        fallback_fail,
    );
    let result = agent
        .run(&Session::new("fallback-session"), prompt)
        .map(|result| result.output);
    (
        result,
        primary_calls.load(Ordering::SeqCst),
        fallback_calls.load(Ordering::SeqCst),
    )
}

fn main() {
    let (primary, primary_calls, fallback_calls) =
        run_prompt("primary answer", false, "fallback answer", false, "hello");
    assert_eq!(primary.expect("primary should succeed"), "primary answer");
    assert_eq!(primary_calls, 1);
    assert_eq!(fallback_calls, 0);

    let (fallback, primary_calls, fallback_calls) =
        run_prompt("primary answer", true, "fallback answer", false, "hello");
    assert_eq!(
        fallback.expect("fallback should succeed"),
        "fallback answer"
    );
    assert_eq!(primary_calls, 1);
    assert_eq!(fallback_calls, 1);

    let (failed, primary_calls, fallback_calls) =
        run_prompt("primary answer", true, "fallback answer", true, "hello");
    assert_eq!(
        failed.expect_err("both models fail").code,
        "MODEL_UNAVAILABLE"
    );
    assert_eq!(primary_calls, 1);
    assert_eq!(fallback_calls, 1);

    println!("provider fallback test: ok");
}
