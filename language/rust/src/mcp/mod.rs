mod client;
mod session;

use std::path::PathBuf;
use std::sync::Arc;

use serde_json::{Map, Value};

use crate::errors::Result;
use crate::model::ToolSpec;
use crate::tool::Tool;

pub use client::McpClient;

use session::Inner;

pub const DEFAULT_PROTOCOL_VERSION: &str = "2024-11-05";

#[derive(Debug, Clone)]
pub struct McpServerConfig {
    pub command: String,
    pub args: Vec<String>,
    pub env: Vec<(String, String)>,
    pub cwd: Option<PathBuf>,
}

impl McpServerConfig {
    pub fn new(command: impl Into<String>) -> Self {
        Self {
            command: command.into(),
            args: Vec::new(),
            env: Vec::new(),
            cwd: None,
        }
    }

    pub fn arg(mut self, arg: impl Into<String>) -> Self {
        self.args.push(arg.into());
        self
    }

    pub fn args<I, S>(mut self, args: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        self.args.extend(args.into_iter().map(Into::into));
        self
    }

    pub fn env(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.env.push((key.into(), value.into()));
        self
    }

    pub fn cwd(mut self, cwd: impl Into<PathBuf>) -> Self {
        self.cwd = Some(cwd.into());
        self
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct McpTool {
    pub name: String,
    pub description: String,
    pub input_schema: Map<String, Value>,
    pub title: String,
    pub annotations: Map<String, Value>,
}

impl McpTool {
    pub fn spec(&self) -> ToolSpec {
        ToolSpec {
            name: self.name.clone(),
            description: self.description.clone(),
            parameters: Some(self.input_schema.clone()),
            risk: None,
        }
    }
}

pub struct McpToolAdapter {
    inner: Arc<Inner>,
    tool: McpTool,
}

impl McpToolAdapter {
    pub fn tool(&self) -> &McpTool {
        &self.tool
    }

    pub fn spec(&self) -> ToolSpec {
        self.tool.spec()
    }
}

impl Tool for McpToolAdapter {
    fn name(&self) -> &str {
        &self.tool.name
    }

    fn description(&self) -> &str {
        &self.tool.description
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        self.inner.call_tool(&self.tool.name, args.clone(), None)
    }
}
