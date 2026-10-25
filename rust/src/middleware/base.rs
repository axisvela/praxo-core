use serde_json::Value;

use crate::agent::RunResult;
use crate::errors::{PraxoError, Result};
use crate::model::{Request, Response, ToolCall};

pub struct RunState {
    pub run_id: String,
    pub prompt: String,
}

pub struct ModelCall {
    pub run_id: String,
    pub session_id: String,
    pub request: Request,
    pub skip: bool,
    pub response: Option<Response>,
}

pub struct MiddlewareToolCall {
    pub run_id: String,
    pub session_id: String,
    pub call: ToolCall,
    pub skip: bool,
    pub result: Option<Value>,
    pub error: Option<PraxoError>,
}

pub struct ToolResult {
    pub value: Value,
    pub error: Option<PraxoError>,
}

pub trait Middleware: Send + Sync {
    fn name(&self) -> &str {
        ""
    }

    fn before_run(&self, _state: &RunState) -> Result<()> {
        Ok(())
    }

    fn before_model(&self, _call: &mut ModelCall) -> Result<()> {
        Ok(())
    }

    fn after_model(&self, _call: &ModelCall, _response: &Response) -> Result<()> {
        Ok(())
    }

    fn before_tool(&self, _call: &mut MiddlewareToolCall) -> Result<()> {
        Ok(())
    }

    fn after_tool(&self, _call: &MiddlewareToolCall, _result: &mut ToolResult) -> Result<()> {
        Ok(())
    }

    fn after_run(&self, _result: Option<&mut RunResult>, _error: Option<&PraxoError>) -> Result<()> {
        Ok(())
    }
}

pub type ModelHandler = Box<dyn Fn(&Request) -> Result<Response> + Send + Sync>;
pub type ModelMiddleware = Box<dyn Fn(ModelHandler) -> ModelHandler + Send + Sync>;

pub fn merge_middleware(items: Vec<Box<dyn Middleware>>) -> Vec<Box<dyn Middleware>> {
    let mut out: Vec<Box<dyn Middleware>> = Vec::new();
    let mut index: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for item in items {
        let name = item.name().to_string();
        if name.is_empty() {
            out.push(item);
            continue;
        }
        if let Some(position) = index.get(&name).copied() {
            out[position] = item;
            continue;
        }
        index.insert(name, out.len());
        out.push(item);
    }
    out
}
