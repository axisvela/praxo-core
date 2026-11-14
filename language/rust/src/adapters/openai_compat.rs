use std::io::BufRead;

use crate::errors::{PraxoError, Result};
use crate::model::{Message, Response, Usage};

pub fn parse_stream<R: BufRead>(
    reader: R,
    on_delta: &mut dyn FnMut(&str) -> Result<()>,
) -> Result<Response> {
    let mut content = String::new();
    let mut finish_reason = None;
    let mut done = false;
    for line in reader.lines() {
        let line = line.map_err(|error| PraxoError::new("MODEL_STREAM", error.to_string()))?;
        let Some(data) = line.trim().strip_prefix("data:") else {
            continue;
        };
        let data = data.trim();
        if data == "[DONE]" {
            done = true;
            break;
        }
        let chunk: serde_json::Value = serde_json::from_str(data).map_err(|_| {
            PraxoError::new("MODEL_STREAM", "openai-compatible: invalid stream chunk")
        })?;
        let choice = &chunk["choices"][0];
        if let Some(reason) = choice["finish_reason"].as_str() {
            finish_reason = Some(reason.to_string());
        }
        if let Some(delta) = choice["delta"]["content"].as_str() {
            if !delta.is_empty() {
                content.push_str(delta);
                on_delta(delta)?;
            }
        }
    }
    if !done && finish_reason.is_none() {
        return Err(PraxoError::new(
            "MODEL_STREAM",
            "openai-compatible: stream ended before completion",
        ));
    }
    Ok(Response {
        message: Message::assistant(content, Vec::new()),
        usage: Usage::default(),
        finish_reason,
    })
}

#[cfg(feature = "http-ureq")]
pub use http::{
    OpenAICompatConfig, OpenAICompatTransport, OpenAICompatible, UreqTransport,
};

#[cfg(feature = "http-ureq")]
mod http {
    use std::io::{BufRead, BufReader};
    use std::time::Duration;

    use serde_json::{json, Map, Value};

    use super::parse_stream;
    use crate::errors::{PraxoError, Result};
    use crate::model::{
        Message, Model, Request, Response, StreamingModel, ToolCall, Usage, ROLE_ASSISTANT,
        ROLE_TOOL,
    };

    pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

    #[derive(Debug, Clone)]
    pub struct OpenAICompatConfig {
        pub base_url: String,
        pub api_key: String,
        pub model: String,
        pub timeout_secs: u64,
    }

    impl Default for OpenAICompatConfig {
        fn default() -> Self {
            Self {
                base_url: DEFAULT_BASE_URL.to_string(),
                api_key: String::new(),
                model: String::new(),
                timeout_secs: 60,
            }
        }
    }

    pub trait OpenAICompatTransport: Send + Sync {
        fn send_json(
            &self,
            url: &str,
            headers: &[(&str, String)],
            payload: &Value,
        ) -> Result<Value>;

        fn send_stream(
            &self,
            url: &str,
            headers: &[(&str, String)],
            payload: &Value,
        ) -> Result<Box<dyn BufRead + Send>>;
    }

    pub struct OpenAICompatible<T: OpenAICompatTransport> {
        config: OpenAICompatConfig,
        transport: T,
    }

    impl<T: OpenAICompatTransport> OpenAICompatible<T> {
        pub fn new(config: OpenAICompatConfig, transport: T) -> Self {
            Self { config, transport }
        }

        pub fn transport(&self) -> &T {
            &self.transport
        }

        pub fn generate(&self, request: &Request) -> Result<Response> {
            self.validate(request)?;
            let payload = self.payload(request, false);
            let data = self.transport.send_json(
                &self.endpoint(),
                &self.headers(),
                &payload,
            )?;
            parse_response(&data)
        }

        pub fn generate_stream(
            &self,
            request: &Request,
            on_delta: &mut dyn FnMut(&str) -> Result<()>,
        ) -> Result<Response> {
            self.validate(request)?;
            let payload = self.payload(request, true);
            let reader = self.transport.send_stream(
                &self.endpoint(),
                &self.headers(),
                &payload,
            )?;
            parse_stream(reader, on_delta)
        }

        fn validate(&self, request: &Request) -> Result<()> {
            if request.model.as_deref().unwrap_or(&self.config.model).is_empty() {
                return Err(PraxoError::new(
                    "MODEL_CONFIG",
                    "openai-compatible: model is required",
                ));
            }
            Ok(())
        }

        fn endpoint(&self) -> String {
            let base = self.config.base_url.trim_end_matches('/');
            if base.ends_with("/chat/completions") {
                base.to_string()
            } else {
                format!("{base}/chat/completions")
            }
        }

        fn headers(&self) -> Vec<(&'static str, String)> {
            let mut headers = Vec::new();
            if !self.config.api_key.is_empty() {
                headers.push((
                    "Authorization",
                    format!("Bearer {}", self.config.api_key),
                ));
            }
            headers.push(("Content-Type", "application/json".to_string()));
            headers
        }

        fn payload(&self, request: &Request, stream: bool) -> Value {
            let mut body = Map::new();
            body.insert(
                "model".to_string(),
                json!(request
                    .model
                    .clone()
                    .unwrap_or_else(|| self.config.model.clone())),
            );
            body.insert(
                "messages".to_string(),
                Value::Array(build_messages(&request.messages)),
            );
            if !request.tools.is_empty() {
                let tools = request
                    .tools
                    .iter()
                    .map(|spec| {
                        json!({
                            "type": "function",
                            "function": {
                                "name": spec.name,
                                "description": spec.description,
                                "parameters": spec.parameters.clone().unwrap_or_else(|| {
                                    json!({"type": "object", "properties": {}})
                                        .as_object()
                                        .cloned()
                                        .unwrap()
                                }),
                            }
                        })
                    })
                    .collect::<Vec<_>>();
                body.insert("tools".to_string(), Value::Array(tools));
                if let Some(choice) = &request.tool_choice {
                    body.insert("tool_choice".to_string(), json!(choice));
                }
            }
            if let Some(format) = &request.response_format {
                if let Some(schema) = &format.schema {
                    let name = format.name.clone().unwrap_or_else(|| "response".to_string());
                    body.insert(
                        "response_format".to_string(),
                        json!({
                            "type": "json_schema",
                            "json_schema": {"name": name, "schema": schema},
                        }),
                    );
                }
            }
            if request.temperature != 0.0 {
                body.insert("temperature".to_string(), json!(request.temperature));
            }
            body.insert("stream".to_string(), json!(stream));
            Value::Object(body)
        }
    }

    impl<T: OpenAICompatTransport> Model for OpenAICompatible<T> {
        fn generate(&self, request: &Request) -> Result<Response> {
            OpenAICompatible::generate(self, request)
        }
    }

    impl<T: OpenAICompatTransport> StreamingModel for OpenAICompatible<T> {
        fn generate_stream(
            &self,
            request: &Request,
            on_delta: &mut dyn FnMut(&str) -> Result<()>,
        ) -> Result<Response> {
            OpenAICompatible::generate_stream(self, request, on_delta)
        }
    }

    pub struct UreqTransport {
        agent: ureq::Agent,
    }

    impl UreqTransport {
        pub fn new(timeout_secs: u64) -> Self {
            let agent = ureq::AgentBuilder::new()
                .timeout(Duration::from_secs(timeout_secs))
                .build();
            Self { agent }
        }
    }

    impl OpenAICompatTransport for UreqTransport {
        fn send_json(
            &self,
            url: &str,
            headers: &[(&str, String)],
            payload: &Value,
        ) -> Result<Value> {
            let mut request = self.agent.post(url);
            for (key, value) in headers {
                request = request.set(*key, value.as_str());
            }
            match request.send_json(payload.clone()) {
                Ok(response) => {
                    let text = response.into_string().map_err(|error| {
                        PraxoError::new(
                            "MODEL_HTTP",
                            format!("openai-compatible: {error}"),
                        )
                    })?;
                    serde_json::from_str(&text).map_err(|error| {
                        PraxoError::new(
                            "PROVIDER_JSON",
                            format!("openai-compatible: {error}"),
                        )
                    })
                }
                Err(ureq::Error::Status(code, response)) => {
                    let body = response.into_string().unwrap_or_default();
                    Err(PraxoError::new(
                        "MODEL_HTTP",
                        format!("openai-compatible: {code}: {body}"),
                    ))
                }
                Err(error) => Err(PraxoError::new(
                    "MODEL_HTTP",
                    format!("openai-compatible: {error}"),
                )),
            }
        }

        fn send_stream(
            &self,
            url: &str,
            headers: &[(&str, String)],
            payload: &Value,
        ) -> Result<Box<dyn BufRead + Send>> {
            let mut request = self.agent.post(url);
            for (key, value) in headers {
                request = request.set(*key, value.as_str());
            }
            match request.send_json(payload.clone()) {
                Ok(response) => Ok(Box::new(BufReader::new(response.into_reader()))),
                Err(ureq::Error::Status(code, response)) => {
                    let body = response.into_string().unwrap_or_default();
                    Err(PraxoError::new(
                        "MODEL_HTTP",
                        format!("openai-compatible: {code}: {body}"),
                    ))
                }
                Err(error) => Err(PraxoError::new(
                    "MODEL_HTTP",
                    format!("openai-compatible: {error}"),
                )),
            }
        }
    }

    impl OpenAICompatible<UreqTransport> {
        pub fn with_ureq(config: OpenAICompatConfig) -> Self {
            let transport = UreqTransport::new(config.timeout_secs);
            Self::new(config, transport)
        }
    }

    fn build_messages(messages: &[Message]) -> Vec<Value> {
        messages
            .iter()
            .map(|message| {
                let mut item = Map::new();
                item.insert("role".to_string(), json!(message.role));
                item.insert(
                    "content".to_string(),
                    message
                        .content
                        .clone()
                        .map(Value::String)
                        .unwrap_or(Value::Null),
                );
                if message.role == ROLE_TOOL {
                    if let Some(tool_id) = &message.tool_id {
                        item.insert("tool_call_id".to_string(), json!(tool_id));
                    }
                }
                if !message.tool_calls.is_empty() {
                    let calls = message
                        .tool_calls
                        .iter()
                        .map(|call| {
                            json!({
                                "id": call.id,
                                "type": "function",
                                "function": {
                                    "name": call.name,
                                    "arguments": serde_json::to_string(&call.arguments)
                                        .unwrap_or_else(|_| "{}".to_string()),
                                },
                            })
                        })
                        .collect::<Vec<_>>();
                    item.insert("tool_calls".to_string(), Value::Array(calls));
                }
                Value::Object(item)
            })
            .collect()
    }

    fn parse_response(data: &Value) -> Result<Response> {
        let choice = data
            .get("choices")
            .and_then(|value| value.get(0))
            .ok_or_else(|| {
                PraxoError::new("MODEL_RESPONSE", "openai-compatible: missing choices")
            })?;
        let message = choice.get("message").ok_or_else(|| {
            PraxoError::new("MODEL_RESPONSE", "openai-compatible: missing message")
        })?;
        let content = message
            .get("content")
            .and_then(|value| value.as_str())
            .map(|value| value.to_string());
        let mut tool_calls = Vec::new();
        if let Some(calls) = message.get("tool_calls").and_then(|value| value.as_array()) {
            for call in calls {
                let id = call
                    .get("id")
                    .and_then(|value| value.as_str())
                    .unwrap_or_default()
                    .to_string();
                let function = call.get("function").ok_or_else(|| {
                    PraxoError::new(
                        "MODEL_RESPONSE",
                        "openai-compatible: tool call missing function",
                    )
                })?;
                let name = function
                    .get("name")
                    .and_then(|value| value.as_str())
                    .unwrap_or_default()
                    .to_string();
                let arguments = parse_arguments(function.get("arguments"))?;
                tool_calls.push(ToolCall {
                    id,
                    name,
                    arguments,
                });
            }
        }
        let usage = Usage {
            input_tokens: data["usage"]["prompt_tokens"].as_i64().unwrap_or(0),
            output_tokens: data["usage"]["completion_tokens"].as_i64().unwrap_or(0),
            cached_tokens: data["usage"]["prompt_tokens_details"]["cached_tokens"]
                .as_i64()
                .unwrap_or(0),
        };
        let finish_reason = choice
            .get("finish_reason")
            .and_then(|value| value.as_str())
            .map(|value| value.to_string());
        Ok(Response {
            message: Message {
                role: ROLE_ASSISTANT.to_string(),
                content,
                content_blocks: Vec::new(),
                tool_calls,
                tool_id: None,
            },
            usage,
            finish_reason,
        })
    }

    fn parse_arguments(value: Option<&Value>) -> Result<Map<String, Value>> {
        match value {
            None | Some(Value::Null) => Ok(Map::new()),
            Some(Value::String(raw)) => {
                if raw.trim().is_empty() {
                    return Ok(Map::new());
                }
                serde_json::from_str::<Map<String, Value>>(raw).map_err(|error| {
                    PraxoError::new(
                        "MODEL_RESPONSE",
                        format!("openai-compatible: invalid tool arguments: {error}"),
                    )
                })
            }
            Some(Value::Object(map)) => Ok(map.clone()),
            _ => Err(PraxoError::new(
                "MODEL_RESPONSE",
                "openai-compatible: invalid tool arguments",
            )),
        }
    }

    #[cfg(test)]
    mod tests {
        use std::io::Cursor;
        use std::sync::{Arc, Mutex};

        use serde_json::json;

        use super::*;
        use crate::model::{Request, ToolSpec};

        struct FakeTransport {
            response: Value,
            payloads: Arc<Mutex<Vec<Value>>>,
            stream: Option<String>,
        }

        impl OpenAICompatTransport for FakeTransport {
            fn send_json(
                &self,
                _url: &str,
                _headers: &[(&str, String)],
                payload: &Value,
            ) -> Result<Value> {
                self.payloads.lock().unwrap().push(payload.clone());
                Ok(self.response.clone())
            }

            fn send_stream(
                &self,
                _url: &str,
                _headers: &[(&str, String)],
                payload: &Value,
            ) -> Result<Box<dyn BufRead + Send>> {
                self.payloads.lock().unwrap().push(payload.clone());
                Ok(Box::new(Cursor::new(
                    self.stream.clone().unwrap_or_default().into_bytes(),
                )))
            }
        }

        fn config() -> OpenAICompatConfig {
            OpenAICompatConfig {
                base_url: "http://localhost:11434/v1".to_string(),
                api_key: String::new(),
                model: "qwen3.5:4b".to_string(),
                timeout_secs: 60,
            }
        }

        #[test]
        fn generate_maps_tool_calls_and_usage() {
            let payloads = Arc::new(Mutex::new(Vec::new()));
            let transport = FakeTransport {
                response: json!({
                    "choices": [{
                        "message": {
                            "role": "assistant",
                            "content": null,
                            "tool_calls": [{
                                "id": "call-1",
                                "function": {"name": "get_time", "arguments": "{\"zone\":\"utc\"}"}
                            }]
                        },
                        "finish_reason": "tool_calls"
                    }],
                    "usage": {"prompt_tokens": 7, "completion_tokens": 3}
                }),
                payloads: payloads.clone(),
                stream: None,
            };
            let model = OpenAICompatible::new(config(), transport);
            let mut request = Request::default();
            request.tools.push(ToolSpec {
                name: "get_time".to_string(),
                description: "Get the time.".to_string(),
                parameters: Some(
                    json!({"type": "object", "properties": {}})
                        .as_object()
                        .cloned()
                        .unwrap(),
                ),
                risk: None,
            });

            let response = model.generate(&request).expect("generate");

            assert_eq!(response.message.tool_calls.len(), 1);
            assert_eq!(response.message.tool_calls[0].name, "get_time");
            assert_eq!(response.message.tool_calls[0].arguments["zone"], "utc");
            assert_eq!(response.usage.input_tokens, 7);
            assert_eq!(response.usage.output_tokens, 3);
            let payload = payloads.lock().unwrap().remove(0);
            assert_eq!(payload["tools"][0]["function"]["parameters"]["type"], "object");
        }

        #[test]
        fn generate_stream_reports_deltas() {
            let payloads = Arc::new(Mutex::new(Vec::new()));
            let transport = FakeTransport {
                response: json!({}),
                payloads: payloads.clone(),
                stream: Some(
                    "data: {\"choices\":[{\"delta\":{\"content\":\"hel\"}}]}\n\
                     data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n\
                     data: [DONE]\n"
                        .to_string(),
                ),
            };
            let model = OpenAICompatible::new(config(), transport);
            let mut deltas = Vec::new();
            let response = model
                .generate_stream(&Request::default(), &mut |delta| {
                    deltas.push(delta.to_string());
                    Ok(())
                })
                .expect("stream");

            assert_eq!(deltas, vec!["hel", "lo"]);
            assert_eq!(response.message.content.as_deref(), Some("hello"));
        }
    }
}
