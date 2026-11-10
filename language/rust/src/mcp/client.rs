use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;

use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};
use crate::tool::{Registry, Tool};

use super::session::Inner;
use super::{McpServerConfig, McpTool, McpToolAdapter, DEFAULT_PROTOCOL_VERSION};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

pub struct McpClient {
    inner: Arc<Inner>,
}

impl McpClient {
    pub fn connect(config: McpServerConfig) -> Result<Self> {
        Self::connect_with_timeout(config, DEFAULT_TIMEOUT)
    }

    pub fn connect_with_timeout(config: McpServerConfig, timeout: Duration) -> Result<Self> {
        let inner = Inner::spawn(config, timeout)?;
        let client = Self { inner };
        if let Err(error) = client.initialize() {
            client.inner.close();
            return Err(error);
        }
        Ok(client)
    }

    pub fn protocol_version(&self) -> String {
        self.inner.protocol_version()
    }

    pub fn server_info(&self) -> Map<String, Value> {
        self.inner.server_info()
    }

    pub fn server_capabilities(&self) -> Map<String, Value> {
        self.inner.server_capabilities()
    }

    pub fn pid(&self) -> Option<u32> {
        self.inner.pid()
    }

    pub fn is_running(&self) -> bool {
        self.inner.is_running()
    }

    pub fn list_tools(&self) -> Result<Vec<McpTool>> {
        self.list_tools_with_timeout(None)
    }

    pub fn list_tools_with_timeout(&self, timeout: Option<Duration>) -> Result<Vec<McpTool>> {
        let mut tools = Vec::new();
        let mut names = HashSet::new();
        let mut cursors = HashSet::new();
        let mut cursor: Option<String> = None;
        loop {
            let mut params = Map::new();
            if let Some(value) = &cursor {
                params.insert("cursor".to_string(), json!(value));
            }
            let params = if params.is_empty() {
                None
            } else {
                Some(Value::Object(params))
            };
            let result = self.inner.request("tools/list", params, timeout)?;
            let raw = result.get("tools").cloned().unwrap_or_else(|| json!([]));
            let items = raw
                .as_array()
                .ok_or_else(|| PraxoError::mcp_protocol("mcp: tools/list tools must be a list"))?;
            for item in items {
                let tool = parse_tool(item)?;
                if !names.insert(tool.name.clone()) {
                    return Err(PraxoError::mcp_duplicate_tool(format!(
                        "mcp: duplicate tool {}",
                        tool.name
                    )));
                }
                tools.push(tool);
            }
            match result.get("nextCursor") {
                None | Some(Value::Null) => break,
                Some(Value::String(value)) if value.is_empty() => break,
                Some(Value::String(value)) => {
                    if !cursors.insert(value.clone()) {
                        return Err(PraxoError::mcp_pagination(
                            "mcp: repeated tool pagination cursor",
                        ));
                    }
                    cursor = Some(value.clone());
                }
                Some(_) => {
                    return Err(PraxoError::mcp_protocol(
                        "mcp: tools/list nextCursor must be a string",
                    ))
                }
            }
        }
        tools.sort_by(|left, right| left.name.cmp(&right.name));
        Ok(tools)
    }

    pub fn call_tool(&self, name: &str, arguments: Map<String, Value>) -> Result<Value> {
        self.call_tool_with_timeout(name, arguments, None)
    }

    pub fn call_tool_with_timeout(
        &self,
        name: &str,
        arguments: Map<String, Value>,
        timeout: Option<Duration>,
    ) -> Result<Value> {
        self.inner.call_tool(name, arguments, timeout)
    }

    pub fn register_tools(&self, registry: &mut Registry) -> Result<Vec<Arc<dyn Tool>>> {
        let tools = self.list_tools()?;
        let mut adapters: Vec<Arc<dyn Tool>> = Vec::new();
        for tool in tools {
            let adapter = Arc::new(McpToolAdapter {
                inner: self.inner.clone(),
                tool,
            });
            registry.register(adapter.clone());
            adapters.push(adapter);
        }
        Ok(adapters)
    }

    pub fn close(&self) {
        self.inner.close();
    }

    fn initialize(&self) -> Result<()> {
        let params = json!({
            "protocolVersion": DEFAULT_PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": {
                "name": "praxo-core",
                "version": crate::SDK_VERSION,
            },
        });
        let result = self.inner.request("initialize", Some(params), None)?;
        let version = result
            .get("protocolVersion")
            .and_then(Value::as_str)
            .unwrap_or("");
        if version.is_empty() {
            return Err(PraxoError::mcp_handshake(
                "mcp: initialize returned no protocol version",
            ));
        }
        self.inner.set_protocol_version(version.to_string());
        if let Some(info) = result.get("serverInfo").and_then(Value::as_object) {
            self.inner.set_server_info(info.clone());
        }
        if let Some(capabilities) = result.get("capabilities").and_then(Value::as_object) {
            self.inner.set_server_capabilities(capabilities.clone());
        }
        self.inner.notify("notifications/initialized", None)
    }
}

fn parse_tool(value: &Value) -> Result<McpTool> {
    let object = value
        .as_object()
        .ok_or_else(|| PraxoError::mcp_protocol("mcp: tool definition must be an object"))?;
    let name = object
        .get("name")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| PraxoError::mcp_protocol("mcp: tool name is required"))?;
    let schema = object
        .get("inputSchema")
        .and_then(Value::as_object)
        .ok_or_else(|| PraxoError::mcp_protocol(format!("mcp: missing input schema for {name}")))?;
    Ok(McpTool {
        name: name.to_string(),
        description: object
            .get("description")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string(),
        input_schema: schema.clone(),
        title: object
            .get("title")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string(),
        annotations: object
            .get("annotations")
            .and_then(Value::as_object)
            .cloned()
            .unwrap_or_default(),
    })
}
