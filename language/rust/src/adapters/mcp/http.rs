use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};

use super::session::{request_message, rpc_error, text_content, text_contents};
use super::McpBackend;

pub const HTTP_PROTOCOL_VERSION: &str = "2025-03-26";

#[derive(Debug, Clone)]
pub struct McpHttpRequest {
    pub message: Value,
    pub session_id: String,
    pub protocol_version: String,
    pub timeout: Duration,
}

#[derive(Debug, Clone)]
pub struct McpHttpResponse {
    pub status: u16,
    pub content_type: String,
    pub body: String,
    pub session_id: Option<String>,
}

pub trait McpHttpTransport: Send + Sync {
    fn post(&self, request: McpHttpRequest) -> Result<McpHttpResponse>;

    fn delete(&self, _session_id: &str, _protocol_version: &str) -> Result<()> {
        Ok(())
    }
}

pub(crate) struct HttpInner {
    transport: Arc<dyn McpHttpTransport>,
    timeout: Duration,
    next_id: AtomicU64,
    closed: AtomicBool,
    protocol_version: Mutex<String>,
    session_id: Mutex<String>,
    server_info: Mutex<Map<String, Value>>,
    server_capabilities: Mutex<Map<String, Value>>,
}

impl HttpInner {
    pub(crate) fn new(
        transport: Arc<dyn McpHttpTransport>,
        timeout: Duration,
        protocol_version: String,
    ) -> Self {
        Self {
            transport,
            timeout,
            next_id: AtomicU64::new(1),
            closed: AtomicBool::new(false),
            protocol_version: Mutex::new(protocol_version),
            session_id: Mutex::new(String::new()),
            server_info: Mutex::new(Map::new()),
            server_capabilities: Mutex::new(Map::new()),
        }
    }

    fn post(&self, message: Value, timeout: Duration) -> Result<McpHttpResponse> {
        let session_id = self
            .session_id
            .lock()
            .expect("mcp http session")
            .clone();
        let protocol_version = self
            .protocol_version
            .lock()
            .expect("mcp http protocol")
            .clone();
        let response = self.transport.post(McpHttpRequest {
            message,
            session_id,
            protocol_version,
            timeout,
        })?;
        if let Some(session) = &response.session_id {
            if !session.is_empty() {
                *self.session_id.lock().expect("mcp http session") = session.clone();
            }
        }
        Ok(response)
    }

    fn response_message(&self, response: &McpHttpResponse, id: Option<u64>) -> Result<Value> {
        let status = response.status;
        let body = response.body.trim();
        if status == 202 || status == 204 || body.is_empty() {
            return Ok(json!({}));
        }
        if !(200..300).contains(&status) {
            let detail = if body.len() > 512 { &body[..512] } else { body };
            return Err(PraxoError::mcp_transport(format!(
                "mcp: HTTP {status}: {detail}"
            )));
        }
        let message = if response
            .content_type
            .to_ascii_lowercase()
            .contains("text/event-stream")
        {
            parse_sse(body, id)?
        } else {
            parse_json(body, id)?
        };
        if let Some(result) = message.get("result").and_then(Value::as_object) {
            if let Some(version) = result.get("protocolVersion").and_then(Value::as_str) {
                if !version.is_empty() {
                    *self.protocol_version.lock().expect("mcp http protocol") =
                        version.to_string();
                }
            }
        }
        Ok(message)
    }
}

impl McpBackend for HttpInner {
    fn request(
        &self,
        method: &str,
        params: Option<Value>,
        timeout: Option<Duration>,
    ) -> Result<Map<String, Value>> {
        if self.closed.load(Ordering::SeqCst) {
            return Err(PraxoError::mcp_closed("mcp: client is closed"));
        }
        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let response = self.post(
            request_message(id, method, params),
            timeout.unwrap_or(self.timeout),
        )?;
        let message = self.response_message(&response, Some(id))?;
        if let Some(error) = message.get("error") {
            return Err(rpc_error(method, error));
        }
        let result = message.get("result").cloned().unwrap_or_else(|| json!({}));
        result
            .as_object()
            .cloned()
            .ok_or_else(|| PraxoError::mcp_protocol(format!("mcp: {method} result must be an object")))
    }

    fn notify(&self, method: &str, params: Option<Value>) -> Result<()> {
        if self.closed.load(Ordering::SeqCst) {
            return Err(PraxoError::mcp_closed("mcp: client is closed"));
        }
        let mut message = Map::new();
        message.insert("jsonrpc".to_string(), json!("2.0"));
        message.insert("method".to_string(), json!(method));
        if let Some(params) = params {
            message.insert("params".to_string(), params);
        }
        let response = self.post(Value::Object(message), self.timeout)?;
        self.response_message(&response, None).map(|_| ())
    }

    fn call_tool(
        &self,
        name: &str,
        arguments: Map<String, Value>,
        timeout: Option<Duration>,
    ) -> Result<Value> {
        if name.is_empty() {
            return Err(PraxoError::mcp_protocol("mcp: tool name is required"));
        }
        let params = json!({"name": name, "arguments": Value::Object(arguments)});
        let result = self.request("tools/call", Some(params), timeout)?;
        if result
            .get("isError")
            .and_then(Value::as_bool)
            .unwrap_or(false)
        {
            return Err(PraxoError::mcp_tool_error(format!(
                "mcp: tool {} failed: {}",
                name,
                text_content(&result)
            )));
        }
        if let Some(structured) = result.get("structuredContent") {
            if !structured.is_null() {
                return Ok(structured.clone());
            }
        }
        let texts = text_contents(&result);
        match texts.len() {
            0 => Ok(Value::Null),
            1 => Ok(Value::String(texts[0].clone())),
            _ => Ok(Value::Array(texts.into_iter().map(Value::String).collect())),
        }
    }

    fn set_protocol_version(&self, value: String) {
        *self.protocol_version.lock().expect("mcp http protocol") = value;
    }

    fn protocol_version(&self) -> String {
        self.protocol_version
            .lock()
            .expect("mcp http protocol")
            .clone()
    }

    fn set_server_info(&self, value: Map<String, Value>) {
        *self.server_info.lock().expect("mcp http server info") = value;
    }

    fn server_info(&self) -> Map<String, Value> {
        self.server_info
            .lock()
            .expect("mcp http server info")
            .clone()
    }

    fn set_server_capabilities(&self, value: Map<String, Value>) {
        *self
            .server_capabilities
            .lock()
            .expect("mcp http capabilities") = value;
    }

    fn server_capabilities(&self) -> Map<String, Value> {
        self.server_capabilities
            .lock()
            .expect("mcp http capabilities")
            .clone()
    }

    fn pid(&self) -> Option<u32> {
        None
    }

    fn is_running(&self) -> bool {
        !self.closed.load(Ordering::SeqCst)
    }

    fn close(&self) {
        if self.closed.swap(true, Ordering::SeqCst) {
            return;
        }
        let session = self
            .session_id
            .lock()
            .expect("mcp http session")
            .clone();
        if !session.is_empty() {
            let protocol = self
                .protocol_version
                .lock()
                .expect("mcp http protocol")
                .clone();
            let _ = self.transport.delete(&session, &protocol);
        }
    }
}

fn parse_json(body: &str, id: Option<u64>) -> Result<Value> {
    let value: Value = serde_json::from_str(body)
        .map_err(|_| PraxoError::mcp_protocol("mcp: server sent invalid JSON"))?;
    match value {
        Value::Array(items) => select_message(items, id)
            .ok_or_else(|| PraxoError::mcp_protocol("mcp: response did not contain a message")),
        Value::Object(_) => Ok(value),
        _ => Err(PraxoError::mcp_protocol(
            "mcp: server sent a non-object JSON-RPC message",
        )),
    }
}

fn parse_sse(body: &str, id: Option<u64>) -> Result<Value> {
    let mut messages = Vec::new();
    let mut data = Vec::new();
    for raw in body.lines() {
        let line = raw.strip_suffix('\r').unwrap_or(raw);
        if line.is_empty() {
            if !data.is_empty() {
                messages.push(parse_json_message(&data.join("\n"))?);
                data.clear();
            }
            continue;
        }
        if line.starts_with(':') {
            continue;
        }
        if let Some(value) = line.strip_prefix("data:") {
            data.push(value.trim_start().to_string());
        }
    }
    if !data.is_empty() {
        messages.push(parse_json_message(&data.join("\n"))?);
    }
    select_message(messages, id)
        .ok_or_else(|| PraxoError::mcp_protocol("mcp: SSE response did not contain a message"))
}

fn parse_json_message(text: &str) -> Result<Value> {
    serde_json::from_str(text)
        .map_err(|_| PraxoError::mcp_protocol("mcp: server sent invalid SSE JSON"))
}

fn select_message(messages: Vec<Value>, id: Option<u64>) -> Option<Value> {
    if let Some(id) = id {
        let matched = messages.iter().find(|message| {
            message
                .get("id")
                .and_then(Value::as_u64)
                .map(|value| value == id)
                .unwrap_or(false)
        });
        if let Some(message) = matched {
            return Some(message.clone());
        }
    }
    messages.into_iter().next()
}
