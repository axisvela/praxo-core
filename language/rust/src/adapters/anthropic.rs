use std::collections::BTreeMap;
use std::io::BufRead;

use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};
use crate::model::{
    Message, Model, Request, Response, StreamingModel, ToolCall, Usage, ROLE_SYSTEM, ROLE_TOOL,
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

    fn send_stream(&self, path: &str, payload: &Value) -> Result<Box<dyn BufRead + Send>> {
        let _ = (path, payload);
        Err(PraxoError::new(
            "PROVIDER_HTTP",
            "anthropic: streaming transport is required",
        ))
    }
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

    pub fn generate_stream(
        &self,
        request: &Request,
        on_delta: &mut dyn FnMut(&str) -> Result<()>,
    ) -> Result<Response> {
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
        let mut payload = self.payload(request);
        payload["stream"] = json!(true);
        let reader = self.transport.send_stream("/v1/messages", &payload)?;
        parse_stream(reader, on_delta)
    }

    fn payload(&self, request: &Request) -> Value {
        let (system, messages) = build_messages(&request.messages);
        let mut payload = Map::new();
        payload.insert(
            "model".to_string(),
            json!(request
                .model
                .clone()
                .unwrap_or_else(|| self.config.model.clone())),
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

impl<T: AnthropicTransport> StreamingModel for Anthropic<T> {
    fn generate_stream(
        &self,
        request: &Request,
        on_delta: &mut dyn FnMut(&str) -> Result<()>,
    ) -> Result<Response> {
        Anthropic::generate_stream(self, request, on_delta)
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

fn parse_stream<R: BufRead>(
    reader: R,
    on_delta: &mut dyn FnMut(&str) -> Result<()>,
) -> Result<Response> {
    let mut content = String::new();
    let mut blocks: BTreeMap<usize, (String, String, String)> = BTreeMap::new();
    let mut input_tokens = 0_i64;
    let mut output_tokens = 0_i64;
    let mut cached_tokens = 0_i64;
    let mut stop_reason = None;
    let mut stopped = false;
    for line in reader.lines() {
        let line = line.map_err(|error| PraxoError::new("MODEL_STREAM", error.to_string()))?;
        let Some(data) = line.trim().strip_prefix("data:") else {
            continue;
        };
        let data = data.trim();
        if data.is_empty() {
            continue;
        }
        let event: Value = serde_json::from_str(data)
            .map_err(|_| PraxoError::new("MODEL_STREAM", "anthropic: invalid stream chunk"))?;
        match event["type"].as_str().unwrap_or("") {
            "message_start" => {
                let usage = &event["message"]["usage"];
                input_tokens = usage["input_tokens"].as_i64().unwrap_or(0);
                cached_tokens = usage["cache_read_input_tokens"].as_i64().unwrap_or(0);
            }
            "content_block_start" => {
                let index = event["index"].as_u64().unwrap_or(0) as usize;
                let block = &event["content_block"];
                if block["type"].as_str() == Some("tool_use") {
                    let arguments = block["input"]
                        .as_object()
                        .filter(|value| !value.is_empty())
                        .map(|value| Value::Object(value.clone()).to_string())
                        .unwrap_or_default();
                    blocks.insert(
                        index,
                        (
                            block["id"].as_str().unwrap_or("").to_string(),
                            block["name"].as_str().unwrap_or("").to_string(),
                            arguments,
                        ),
                    );
                }
            }
            "content_block_delta" => {
                let index = event["index"].as_u64().unwrap_or(0) as usize;
                let delta = &event["delta"];
                match delta["type"].as_str().unwrap_or("") {
                    "text_delta" => {
                        let text = delta["text"].as_str().unwrap_or("");
                        if !text.is_empty() {
                            content.push_str(text);
                            on_delta(text)?;
                        }
                    }
                    "input_json_delta" => {
                        let partial = delta["partial_json"].as_str().unwrap_or("");
                        if let Some((_, _, arguments)) = blocks.get_mut(&index) {
                            arguments.push_str(partial);
                        }
                    }
                    _ => {}
                }
            }
            "message_delta" => {
                if let Some(reason) = event["delta"]["stop_reason"].as_str() {
                    stop_reason = Some(reason.to_string());
                }
                output_tokens = event["usage"]["output_tokens"]
                    .as_i64()
                    .unwrap_or(output_tokens);
            }
            "message_stop" => {
                stopped = true;
            }
            "error" => {
                return Err(PraxoError::new(
                    "MODEL_STREAM",
                    format!(
                        "anthropic: {}",
                        event["error"]["message"].as_str().unwrap_or("stream error")
                    ),
                ));
            }
            _ => {}
        }
    }
    if !stopped && stop_reason.is_none() {
        return Err(PraxoError::new(
            "MODEL_STREAM",
            "anthropic: stream ended before completion",
        ));
    }
    let mut calls = Vec::new();
    for (_, (id, name, raw_arguments)) in blocks {
        if name.is_empty() {
            continue;
        }
        let arguments = if raw_arguments.is_empty() {
            Map::new()
        } else {
            serde_json::from_str::<Value>(&raw_arguments)
                .ok()
                .and_then(|value| value.as_object().cloned())
                .ok_or_else(|| PraxoError::new("PROVIDER_JSON", "invalid tool call arguments"))?
        };
        calls.push(ToolCall {
            id,
            name,
            arguments,
        });
    }
    Ok(Response {
        message: Message::assistant(content, calls),
        usage: Usage {
            input_tokens,
            output_tokens,
            cached_tokens,
        },
        finish_reason: stop_reason,
    })
}

fn parse_response(data: &Value) -> Result<Response> {
    if let Some(error) = data.get("error") {
        return Err(PraxoError::new(
            "MODEL_HTTP",
            format!(
                "anthropic: {}",
                error["message"].as_str().unwrap_or("error")
            ),
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
