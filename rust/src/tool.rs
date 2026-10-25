use std::collections::HashMap;
use std::sync::Arc;

use serde_json::{Map, Value};

use crate::errors::{PraxoError, Result};
use crate::model::ToolSpec;

pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn invoke(&self, args: &Map<String, Value>) -> Result<Value>;
}

pub struct FuncTool<F>
where
    F: Fn(&Map<String, Value>) -> Result<Value> + Send + Sync,
{
    name: String,
    description: String,
    function: F,
}

impl<F> FuncTool<F>
where
    F: Fn(&Map<String, Value>) -> Result<Value> + Send + Sync,
{
    pub fn new(name: impl Into<String>, description: impl Into<String>, function: F) -> Self {
        Self {
            name: name.into(),
            description: description.into(),
            function,
        }
    }
}

impl<F> Tool for FuncTool<F>
where
    F: Fn(&Map<String, Value>) -> Result<Value> + Send + Sync,
{
    fn name(&self) -> &str {
        &self.name
    }

    fn description(&self) -> &str {
        &self.description
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        (self.function)(args)
    }
}

#[derive(Default)]
pub struct Registry {
    tools: HashMap<String, Arc<dyn Tool>>,
}

impl Registry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn register(&mut self, tool: Arc<dyn Tool>) {
        self.tools.insert(tool.name().to_string(), tool);
    }

    pub fn get(&self, name: &str) -> Result<Arc<dyn Tool>> {
        self.tools
            .get(name)
            .cloned()
            .ok_or_else(|| PraxoError::tool_not_found(format!("tool not found: {name}")))
    }

    pub fn specs(&self) -> Vec<ToolSpec> {
        let mut specs: Vec<ToolSpec> = self
            .tools
            .values()
            .map(|tool| ToolSpec {
                name: tool.name().to_string(),
                description: tool.description().to_string(),
                parameters: None,
                risk: None,
            })
            .collect();
        specs.sort_by(|left, right| left.name.cmp(&right.name));
        specs
    }

    pub fn len(&self) -> usize {
        self.tools.len()
    }

    pub fn is_empty(&self) -> bool {
        self.tools.is_empty()
    }
}
