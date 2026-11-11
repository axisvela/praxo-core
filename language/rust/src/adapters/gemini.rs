use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};
use crate::model::{
    Message, Model, Request, Response, ToolCall, Usage, ROLE_ASSISTANT, ROLE_SYSTEM, ROLE_TOOL,
};

pub const DEFAULT_BASE_URL: &str = "https://generativelanguage.googleapis.com";

#[derive(Debug, Clone)]
pub struct GeminiConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub max_output_tokens: i64,
}

impl Default for GeminiConfig {
    fn default() -> Self {
        Self {
            base_url: DEFAULT_BASE_URL.to_string(),
            api_key: String::new(),
            model: String::new(),
            max_output_tokens: 0,
        }
    }
}

pub trait GeminiTransport: Send + Sync {
    fn send(&self, path: &str, payload: &Value) -> Result<Value>;
}

pub struct Gemini<T: GeminiTransport> {
    config: GeminiConfig,
    transport: T,
}

impl<T: GeminiTransport> Gemini<T> {
    pub fn new(config: GeminiConfig, transport: T) -> Self {
        Self { config, transport }
    }

    pub fn transport(&self) -> &T {
        &self.transport
    }

    pub fn generate(&self, request: &Request) -> Result<Response> {
        if self.config.api_key.is_empty() {
            return Err(PraxoError::new(
                "MODEL_CONFIG",
                "gemini: API key is required",
            ));
        }
        if self.config.model.is_empty() {
            return Err(PraxoError::new(
                "MODEL_CONFIG",
                "gemini: model is required",
            ));
        }
        let payload = self.payload(request);
        let path = format!(
            "/v1beta/models/{}:generateContent",
            urlencoding(&self.config.model)
        );
        let data = self.transport.send(&path, &payload)?;
        parse_response(&data)
    }

    fn payload(&self, request: &Request) -> Value {
        let (system, contents) = build_contents(&request.messages);
        let mut payload = Map::new();
        payload.insert("contents".to_string(), Value::Array(contents));
        if let Some(system) = system {
            payload.insert("system_instruction".to_string(), system);
        }
        if !request.tools.is_empty() {
            let declarations = request
                .tools
                .iter()
                .map(|spec| {
                    json!({
                        "name": spec.name,
                        "description": spec.description,
                        "parameters": spec.parameters.clone().unwrap_or_else(|| {
                            json!({"type": "object", "properties": {}})
                                .as_object()
                                .cloned()
                                .unwrap()
                        })
                    })
                })
                .collect::<Vec<_>>();
            payload.insert(
                "tools".to_string(),
                json!([{"functionDeclarations": declarations}]),
            );
            payload.insert(
                "toolConfig".to_string(),
                json!({"functionCallingConfig": {"mode": tool_mode(request.tool_choice.as_deref())}}),
            );
        }
        if request.temperature != 0.0 || self.config.max_output_tokens > 0 {
            payload.insert(
                "generationConfig".to_string(),
                json!({
                    "temperature": request.temperature,
                    "maxOutputTokens": self.config.max_output_tokens
                }),
            );
        }
        Value::Object(payload)
    }
}

impl<T: GeminiTransport> Model for Gemini<T> {
    fn generate(&self, request: &Request) -> Result<Response> {
        Gemini::generate(self, request)
    }
}

fn build_contents(messages: &[Message]) -> (Option<Value>, Vec<Value>) {
    let mut system_parts = Vec::new();
    let mut contents = Vec::new();
    let mut tool_parts = Vec::new();
    let mut names = std::collections::HashMap::new();
    for message in messages {
        if message.role == ROLE_SYSTEM {
            if let Some(content) = &message.content {
                if !content.is_empty() {
                    system_parts.push(json!({"text": content}));
                }
            }
            continue;
        }
        if message.role == ROLE_TOOL {
            let name = message
                .tool_id
                .as_ref()
                .and_then(|id| names.get(id).cloned())
                .or_else(|| message.tool_id.clone())
                .unwrap_or_else(|| "tool".to_string());
            tool_parts.push(json!({
                "functionResponse": {
                    "name": name,
                    "response": {"result": message.content.clone().unwrap_or_default()}
                }
            }));
            continue;
        }
        flush_tools(&mut contents, &mut tool_parts);
        let parts = message_parts(message);
        if !parts.is_empty() {
            contents.push(json!({
                "role": if message.role == ROLE_ASSISTANT { "model" } else { "user" },
                "parts": parts
            }));
        }
        for call in &message.tool_calls {
            if !call.id.is_empty() && !call.name.is_empty() {
                names.insert(call.id.clone(), call.name.clone());
            }
        }
    }
    flush_tools(&mut contents, &mut tool_parts);
    let system = if system_parts.is_empty() {
        None
    } else {
        Some(json!({"parts": system_parts}))
    };
    (system, contents)
}

fn flush_tools(contents: &mut Vec<Value>, parts: &mut Vec<Value>) {
    if parts.is_empty() {
        return;
    }
    contents.push(json!({"role": "user", "parts": parts.clone()}));
    parts.clear();
}

fn message_parts(message: &Message) -> Vec<Value> {
    let mut parts = Vec::new();
    if let Some(text) = &message.content {
        if !text.is_empty() {
            parts.push(json!({"text": text}));
        }
    }
    for block in &message.content_blocks {
        if block.kind == "text" {
            if let Some(text) = &block.text {
                if !text.is_empty() {
                    parts.push(json!({"text": text}));
                }
            }
        }
    }
    for call in &message.tool_calls {
        parts.push(json!({
            "functionCall": {"name": call.name, "args": call.arguments}
        }));
    }
    parts
}

fn tool_mode(choice: Option<&str>) -> &'static str {
    match choice {
        Some("required") => "ANY",
        Some("none") => "NONE",
        _ => "AUTO",
    }
}

fn parse_response(data: &Value) -> Result<Response> {
    if let Some(error) = data.get("error") {
        return Err(PraxoError::new(
            "MODEL_HTTP",
            format!("gemini: {}", error["message"].as_str().unwrap_or("error")),
        ));
    }
    let candidates = data["candidates"].as_array().cloned().unwrap_or_default();
    let candidate = candidates
        .first()
        .ok_or_else(|| PraxoError::new("MODEL_HTTP", "gemini: empty response"))?;
    let mut text = String::new();
    let mut calls = Vec::new();
    if let Some(parts) = candidate["content"]["parts"].as_array() {
        for part in parts {
            text.push_str(part["text"].as_str().unwrap_or(""));
            if let Some(call) = part.get("functionCall") {
                calls.push(ToolCall {
                    id: format!("call-{}", calls.len() + 1),
                    name: call["name"].as_str().unwrap_or("").to_string(),
                    arguments: call["args"].as_object().cloned().unwrap_or_default(),
                });
            }
        }
    }
    let usage = &data["usageMetadata"];
    Ok(Response {
        message: Message::assistant(text, calls),
        usage: Usage {
            input_tokens: usage["promptTokenCount"].as_i64().unwrap_or(0),
            output_tokens: usage["candidatesTokenCount"].as_i64().unwrap_or(0),
            cached_tokens: usage["cachedContentTokenCount"].as_i64().unwrap_or(0),
        },
        finish_reason: candidate["finishReason"].as_str().map(str::to_string),
    })
}

fn urlencoding(value: &str) -> String {
    let mut out = String::new();
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'~') {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

