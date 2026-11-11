use std::sync::Mutex;

use praxo_core::adapters::anthropic::{
    Anthropic, AnthropicConfig, AnthropicTransport,
};
use praxo_core::adapters::gemini::{
    Gemini, GeminiConfig, GeminiTransport,
};
use praxo_core::errors::Result;
use praxo_core::model::{
    Message, Request, ToolSpec, ROLE_SYSTEM,
};
use serde_json::{json, Value};

struct AnthropicFake {
    seen: Mutex<Value>,
}

impl AnthropicTransport for AnthropicFake {
    fn send(&self, path: &str, payload: &Value) -> Result<Value> {
        assert_eq!(path, "/v1/messages");
        *self.seen.lock().unwrap() = payload.clone();
        Ok(json!({
            "content": [
                {"type": "text", "text": "hello"},
                {"type": "tool_use", "id": "tool-1", "name": "echo", "input": {"text": "hi"}}
            ],
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 3, "output_tokens": 4, "cache_read_input_tokens": 2}
        }))
    }
}

#[test]
fn anthropic_maps_request_and_response() {
    let adapter = Anthropic::new(
        AnthropicConfig {
            api_key: "ak".to_string(),
            model: "claude-test".to_string(),
            ..AnthropicConfig::default()
        },
        AnthropicFake {
            seen: Mutex::new(Value::Null),
        },
    );
    let mut request = Request::of(vec![
        Message::text(ROLE_SYSTEM, "be brief"),
        Message::text("user", "hi"),
    ]);
    request.tools = vec![ToolSpec {
        name: "echo".to_string(),
        description: "Echo".to_string(),
        parameters: Some(json!({"type": "object"}).as_object().cloned().unwrap()),
        risk: None,
    }];
    request.tool_choice = Some("auto".to_string());
    let response = adapter.generate(&request).unwrap();
    assert_eq!(response.message.content.as_deref(), Some("hello"));
    assert_eq!(response.message.tool_calls[0].id, "tool-1");
    assert_eq!(response.message.tool_calls[0].arguments["text"], "hi");
    assert_eq!(response.usage.cached_tokens, 2);
    let seen = adapter.transport().seen.lock().unwrap();
    assert_eq!(seen["system"], "be brief");
    assert_eq!(seen["tool_choice"]["type"], "auto");
    assert_eq!(seen["tools"][0]["input_schema"]["type"], "object");
}

struct GeminiFake {
    seen: Mutex<(String, Value)>,
}

impl GeminiTransport for GeminiFake {
    fn send(&self, path: &str, payload: &Value) -> Result<Value> {
        *self.seen.lock().unwrap() = (path.to_string(), payload.clone());
        Ok(json!({
            "candidates": [{
                "content": {"parts": [
                    {"text": "hello"},
                    {"functionCall": {"name": "echo", "args": {"text": "hi"}}}
                ]},
                "finishReason": "STOP"
            }],
            "usageMetadata": {
                "promptTokenCount": 3,
                "candidatesTokenCount": 4,
                "cachedContentTokenCount": 2
            }
        }))
    }
}

#[test]
fn gemini_maps_request_and_response() {
    let adapter = Gemini::new(
        GeminiConfig {
            api_key: "gk".to_string(),
            model: "gemini-test".to_string(),
            ..GeminiConfig::default()
        },
        GeminiFake {
            seen: Mutex::new((String::new(), Value::Null)),
        },
    );
    let mut request = Request::of(vec![
        Message::text(ROLE_SYSTEM, "be brief"),
        Message::text("user", "hi"),
    ]);
    request.tools = vec![ToolSpec {
        name: "echo".to_string(),
        description: "Echo".to_string(),
        parameters: Some(json!({"type": "object"}).as_object().cloned().unwrap()),
        risk: None,
    }];
    request.tool_choice = Some("auto".to_string());
    let response = adapter.generate(&request).unwrap();
    assert_eq!(response.message.content.as_deref(), Some("hello"));
    assert_eq!(response.message.tool_calls[0].name, "echo");
    assert_eq!(response.usage.cached_tokens, 2);
    let seen = adapter.transport().seen.lock().unwrap();
    assert!(seen.0.ends_with(":generateContent"));
    assert_eq!(seen.1["system_instruction"]["parts"][0]["text"], "be brief");
    assert_eq!(seen.1["toolConfig"]["functionCallingConfig"]["mode"], "AUTO");
}
