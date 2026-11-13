use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::middleware::{ModelHandler, ModelMiddleware};
use praxo_core::model::{Message, Model, Request, Response};

fn retry_model(max_attempts: usize) -> ModelMiddleware {
    Box::new(move |next: ModelHandler| {
        Box::new(move |request: &Request| {
            let mut last_error: Option<PraxoError> = None;
            for attempt in 1..=max_attempts {
                match next(request) {
                    Ok(response) => return Ok(response),
                    Err(error) => {
                        if error.code != "MODEL_UNAVAILABLE" || attempt == max_attempts {
                            return Err(error);
                        }
                        last_error = Some(error);
                    }
                }
            }
            Err(last_error
                .unwrap_or_else(|| PraxoError::new("MODEL_UNAVAILABLE", "model unavailable")))
        })
    })
}

struct FlakyModel {
    failures: usize,
    calls: AtomicUsize,
}

impl Model for FlakyModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        let call = self.calls.fetch_add(1, Ordering::SeqCst) + 1;
        if call <= self.failures {
            return Err(PraxoError::new("MODEL_UNAVAILABLE", "temporary outage"));
        }
        Ok(Response {
            message: Message::assistant("status: green", Vec::new()),
            ..Response::default()
        })
    }
}

fn build_agent(model: Arc<FlakyModel>, max_attempts: usize) -> Agent {
    let mut options = AgentOptions::new(model);
    options.model_middleware = vec![retry_model(max_attempts)];
    options.max_steps = 2;
    Agent::new(options).expect("agent")
}

fn main() {
    let recovered = Arc::new(FlakyModel {
        failures: 2,
        calls: AtomicUsize::new(0),
    });
    let agent = build_agent(recovered.clone(), 3);
    let result = agent
        .run(&Session::new("retry"), "Check the status.")
        .expect("recovered run");
    assert_eq!(result.output, "status: green");
    assert_eq!(recovered.calls.load(Ordering::SeqCst), 3);

    let exhausted = Arc::new(FlakyModel {
        failures: 3,
        calls: AtomicUsize::new(0),
    });
    let agent = build_agent(exhausted.clone(), 3);
    let error = agent
        .run(&Session::new("retry"), "Check the status.")
        .expect_err("exhausted run");
    assert_eq!(error.code, "MODEL_UNAVAILABLE");
    assert_eq!(exhausted.calls.load(Ordering::SeqCst), 3);

    println!("retry test: ok");
}
