use std::collections::HashMap;
use std::sync::Mutex;

use crate::agent::RunResult;
use crate::errors::{PraxoError, Result};
use crate::middleware::{Middleware, MiddlewareToolCall, ModelCall, RunState};

#[derive(Default)]
struct Count {
    models: usize,
    tools: usize,
}

pub struct CallLimitMiddleware {
    model_limit: usize,
    tool_limit: usize,
    counts: Mutex<HashMap<String, Count>>,
}

impl CallLimitMiddleware {
    pub fn new(model_limit: usize, tool_limit: usize) -> Self {
        Self {
            model_limit,
            tool_limit,
            counts: Mutex::new(HashMap::new()),
        }
    }
}

impl Middleware for CallLimitMiddleware {
    fn name(&self) -> &str {
        "call-limit"
    }

    fn before_run(&self, state: &RunState) -> Result<()> {
        self.counts
            .lock()
            .expect("call limit poisoned")
            .insert(state.run_id.clone(), Count::default());
        Ok(())
    }

    fn before_model(&self, call: &mut ModelCall) -> Result<()> {
        let mut counts = self.counts.lock().expect("call limit poisoned");
        let count = counts.entry(call.run_id.clone()).or_default();
        count.models += 1;
        if self.model_limit > 0 && count.models > self.model_limit {
            return Err(PraxoError::model_call_limit());
        }
        Ok(())
    }

    fn before_tool(&self, call: &mut MiddlewareToolCall) -> Result<()> {
        let mut counts = self.counts.lock().expect("call limit poisoned");
        let count = counts.entry(call.run_id.clone()).or_default();
        count.tools += 1;
        if self.tool_limit > 0 && count.tools > self.tool_limit {
            return Err(PraxoError::tool_call_limit());
        }
        Ok(())
    }

    fn after_run(
        &self,
        result: Option<&mut RunResult>,
        _error: Option<&PraxoError>,
    ) -> Result<()> {
        if let Some(result) = result {
            self.counts
                .lock()
                .expect("call limit poisoned")
                .remove(&result.run_id);
        }
        Ok(())
    }
}
