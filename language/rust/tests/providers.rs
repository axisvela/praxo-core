use std::io::{BufRead, Cursor};
use std::sync::Mutex;

use praxo_core::adapters::anthropic::{Anthropic, AnthropicConfig, AnthropicTransport};
use praxo_core::adapters::gemini::{Gemini, GeminiConfig, GeminiTransport};
use praxo_core::errors::Result;
use praxo_core::model::{Message, Request, StreamingModel, ToolSpec, ROLE_SYSTEM};
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

struct AnthropicStreamFake;

impl AnthropicTransport for AnthropicStreamFake {
    fn send(&self, _path: &str, _payload: &Value) -> Result<Value> {
        panic!("send should not be called")
    }

    fn send_stream(&self, path: &str, payload: &Value) -> Result<Box<dyn BufRead + Send>> {
        assert_eq!(path, "/v1/messages");
        assert_eq!(payload["stream"], true);
        let stream = r#"data: {"type":"message_start","message":{"usage":{"input_tokens":4}}}

data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}

data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-1","name":"echo","input":{}}}

data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}

data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}

data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}

data: {"type":"message_stop"}

"#;
        Ok(Box::new(Cursor::new(stream.as_bytes().to_vec())))
    }
}

#[test]
fn anthropic_streams_text_and_tools() {
    let adapter = Anthropic::new(
        AnthropicConfig {
            api_key: "ak".to_string(),
            model: "claude-test".to_string(),
            ..AnthropicConfig::default()
        },
        AnthropicStreamFake,
    );
    let request = Request::of(vec![Message::text("user", "hi")]);
    let mut deltas = Vec::new();
    let response = adapter
        .generate_stream(&request, &mut |delta| {
            deltas.push(delta.to_string());
            Ok(())
        })
        .unwrap();
    assert_eq!(deltas, vec!["he", "llo"]);
    assert_eq!(response.message.content.as_deref(), Some("hello"));
    assert_eq!(response.message.tool_calls[0].id, "call-1");
    assert_eq!(response.message.tool_calls[0].name, "echo");
    assert_eq!(response.message.tool_calls[0].arguments["text"], "hi");
    assert_eq!(response.usage.input_tokens, 4);
    assert_eq!(response.usage.output_tokens, 2);
    assert_eq!(response.finish_reason.as_deref(), Some("tool_use"));
}

struct GeminiFake {
    seen: Mutex<(String, Value)>,
}

impl GeminiTransport for GeminiFake {
    fn send_stream(&self, path: &str, payload: &Value) -> Result<Box<dyn BufRead + Send>> {
        *self.seen.lock().unwrap() = (path.to_string(), payload.clone());
        let body = concat!(
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"he\"}]}}]}\n\n",
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"llo\"},",
            "{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},",
            "\"finishReason\":\"STOP\"}],",
            "\"usageMetadata\":{\"promptTokenCount\":4,\"candidatesTokenCount\":2,",
            "\"cachedContentTokenCount\":1}}"
        );
        Ok(Box::new(Cursor::new(body)))
    }

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
    assert_eq!(
        seen.1["toolConfig"]["functionCallingConfig"]["mode"],
        "AUTO"
    );
}

#[test]
fn gemini_reassembles_stream() {
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
    let request = Request::of(vec![Message::text("user", "hi")]);
    let mut deltas = Vec::new();
    let response = adapter
        .generate_stream(&request, &mut |delta| {
            deltas.push(delta.to_string());
            Ok(())
        })
        .unwrap();
    assert_eq!(deltas, vec!["he", "llo"]);
    assert_eq!(response.message.content.as_deref(), Some("hello"));
    assert_eq!(response.message.tool_calls[0].name, "echo");
    assert_eq!(response.message.tool_calls[0].arguments["text"], "hi");
    assert_eq!(response.usage.input_tokens, 4);
    assert_eq!(response.usage.output_tokens, 2);
    assert_eq!(response.usage.cached_tokens, 1);
    assert_eq!(response.finish_reason.as_deref(), Some("STOP"));
    let seen = adapter.transport().seen.lock().unwrap();
    assert!(seen.0.contains(":streamGenerateContent?alt=sse"));
}
