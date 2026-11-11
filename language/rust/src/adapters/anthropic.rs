use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};
use crate::model::{
    Message, Model, Request, Response, ToolCall, Usage, ROLE_SYSTEM, ROLE_TOOL,
};

pub const DEFAULT_BASE_URL: &str = "https://api.anthropic.com";
pub const DEFAULT_VERSION: &str = "2023-06-01";

#[derive(Debug, Clone)]
pub struct AnthropicConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub version: String,
    pub max_tokens: i64,
}

impl Default for AnthropicConfig {
    fn default() -> Self {
        Self {
            base_url: DEFAULT_BASE_URL.to_string(),
            api_key: String::new(),
            model: String::new(),
            version: DEFAULT_VERSION.to_string(),
            max_tokens: 1024,
        }
    }
}

pub trait AnthropicTransport: Send + Sync {
    fn send(&self, path: &str, payload: &Value) -> Result<Value>;
}

pub struct Anthropic<T: AnthropicTransport> {
    config: AnthropicConfig,
    transport: T,
}

impl<T: AnthropicTransport> Anthropic<T> {
    pub fn new(config: AnthropicConfig, transport: T) -> Self {
        Self { config, transport }
    }

    pub fn transport(&self) -> &T {
        &self.transport
    }

    pub fn generate(&self, request: &Request) -> Result<Response> {
        if self.config.api_key.is_empty() {
            return Err(PraxoError::new(
                "MODEL_CONFIG",
                "anthropic: API key is required",
            ));
        }
        if self.config.model.is_empty() {
            return Err(PraxoError::new(
                "MODEL_CONFIG",
                "anthropic: model is required",
            ));
        }
        let payload = self.payload(request);
        let data = self.transport.send("/v1/messages", &payload)?;
        parse_response(&data)
    }

    fn payload(&self, request: &Request) -> Value {
        let (system, messages) = build_messages(&request.messages);
        let mut payload = Map::new();
        payload.insert(
            "model".to_string(),
            json!(request.model.clone().unwrap_or_else(|| self.config.model.clone())),
        );
        payload.insert("max_tokens".to_string(), json!(self.config.max_tokens));
        payload.insert("messages".to_string(), Value::Array(messages));
        if !system.is_empty() {
            payload.insert("system".to_string(), json!(system));
        }
        if !request.tools.is_empty() {
            let tools = request
                .tools
                .iter()
                .map(|spec| {
                    json!({
                        "name": spec.name,
                        "description": spec.description,
                        "input_schema": spec.parameters.clone().unwrap_or_else(|| {
                            json!({"type": "object", "properties": {}})
                                .as_object()
                                .cloned()
                                .unwrap()
                        })
                    })
                })
                .collect::<Vec<_>>();
            payload.insert("tools".to_string(), Value::Array(tools));
            if let Some(choice) = tool_choice(request.tool_choice.as_deref()) {
                payload.insert("tool_choice".to_string(), choice);
            }
        }
        if request.temperature != 0.0 {
            payload.insert("temperature".to_string(), json!(request.temperature));
        }
        Value::Object(payload)
    }
}

impl<T: AnthropicTransport> Model for Anthropic<T> {
    fn generate(&self, request: &Request) -> Result<Response> {
        Anthropic::generate(self, request)
    }
}

fn build_messages(messages: &[Message]) -> (String, Vec<Value>) {
    let mut system = Vec::new();
    let mut out = Vec::new();
    let mut tool_results = Vec::new();
    for message in messages {
        if message.role == ROLE_SYSTEM {
            if let Some(content) = &message.content {
                if !content.is_empty() {
                    system.push(content.clone());
                }
            }
            continue;
        }
        if message.role == ROLE_TOOL {
            tool_results.push(json!({
                "type": "tool_result",
                "tool_use_id": message.tool_id.clone().unwrap_or_default(),
                "content": message.content.clone().unwrap_or_default()
            }));
            continue;
        }
        flush_tools(&mut out, &mut tool_results);
        let content = message_content(message);
        if !content.is_empty() {
            out.push(json!({"role": message.role, "content": content}));
        }
    }
    flush_tools(&mut out, &mut tool_results);
    (system.join("\n\n"), out)
}

fn flush_tools(out: &mut Vec<Value>, results: &mut Vec<Value>) {
    if results.is_empty() {
        return;
    }
    out.push(json!({"role": "user", "content": results.clone()}));
    results.clear();
}

fn message_content(message: &Message) -> Vec<Value> {
    let mut content = Vec::new();
    if let Some(text) = &message.content {
        if !text.is_empty() {
            content.push(json!({"type": "text", "text": text}));
        }
    }
    for block in &message.content_blocks {
        if block.kind == "text" {
            if let Some(text) = &block.text {
                if !text.is_empty() {
                    content.push(json!({"type": "text", "text": text}));
                }
            }
        }
    }
    for call in &message.tool_calls {
        content.push(json!({
            "type": "tool_use",
            "id": call.id,
            "name": call.name,
            "input": call.arguments
        }));
    }
    content
}

fn tool_choice(choice: Option<&str>) -> Option<Value> {
    match choice {
        Some("auto") => Some(json!({"type": "auto"})),
        Some("required") => Some(json!({"type": "any"})),
        Some("none") => Some(json!({"type": "none"})),
        _ => None,
    }
}

fn parse_response(data: &Value) -> Result<Response> {
    if let Some(error) = data.get("error") {
        return Err(PraxoError::new(
            "MODEL_HTTP",
            format!("anthropic: {}", error["message"].as_str().unwrap_or("error")),
        ));
    }
    let mut text = String::new();
    let mut calls = Vec::new();
    if let Some(blocks) = data["content"].as_array() {
        for block in blocks {
            match block["type"].as_str().unwrap_or("") {
                "text" => text.push_str(block["text"].as_str().unwrap_or("")),
                "tool_use" => calls.push(ToolCall {
                    id: block["id"].as_str().unwrap_or("").to_string(),
                    name: block["name"].as_str().unwrap_or("").to_string(),
                    arguments: block["input"].as_object().cloned().unwrap_or_default(),
                }),
                _ => {}
            }
        }
    }
    let usage = &data["usage"];
    Ok(Response {
        message: Message::assistant(text, calls),
        usage: Usage {
            input_tokens: usage["input_tokens"].as_i64().unwrap_or(0),
            output_tokens: usage["output_tokens"].as_i64().unwrap_or(0),
            cached_tokens: usage["cache_read_input_tokens"].as_i64().unwrap_or(0),
        },
        finish_reason: data["stop_reason"].as_str().map(str::to_string),
    })
}

