use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::errors::Result;

pub const ROLE_SYSTEM: &str = "system";
pub const ROLE_USER: &str = "user";
pub const ROLE_ASSISTANT: &str = "assistant";
pub const ROLE_TOOL: &str = "tool";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ContentBlock {
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(default, rename = "image_url", skip_serializing_if = "Option::is_none")]
    pub image_url: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ToolCall {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub arguments: Map<String, Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Message {
    pub role: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    #[serde(
        default,
        rename = "contentBlocks",
        skip_serializing_if = "Vec::is_empty"
    )]
    pub content_blocks: Vec<ContentBlock>,
    #[serde(default, rename = "toolCalls", skip_serializing_if = "Vec::is_empty")]
    pub tool_calls: Vec<ToolCall>,
    #[serde(default, rename = "toolId", skip_serializing_if = "Option::is_none")]
    pub tool_id: Option<String>,
}

impl Message {
    pub fn text(role: &str, content: impl Into<String>) -> Self {
        Self {
            role: role.to_string(),
            content: Some(content.into()),
            content_blocks: Vec::new(),
            tool_calls: Vec::new(),
            tool_id: None,
        }
    }

    pub fn assistant(content: impl Into<String>, tool_calls: Vec<ToolCall>) -> Self {
        Self {
            role: ROLE_ASSISTANT.to_string(),
            content: Some(content.into()),
            content_blocks: Vec::new(),
            tool_calls,
            tool_id: None,
        }
    }

    pub fn tool(content: impl Into<String>, tool_id: impl Into<String>) -> Self {
        Self {
            role: ROLE_TOOL.to_string(),
            content: Some(content.into()),
            content_blocks: Vec::new(),
            tool_calls: Vec::new(),
            tool_id: Some(tool_id.into()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ToolSpec {
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parameters: Option<Map<String, Value>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub risk: Option<String>,
}

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq)]
pub struct Usage {
    #[serde(rename = "inputTokens")]
    pub input_tokens: i64,
    #[serde(rename = "outputTokens")]
    pub output_tokens: i64,
    #[serde(rename = "cachedTokens", default)]
    pub cached_tokens: i64,
}

impl Usage {
    pub fn plus(self, other: Usage) -> Usage {
        Usage {
            input_tokens: self.input_tokens + other.input_tokens,
            output_tokens: self.output_tokens + other.output_tokens,
            cached_tokens: self.cached_tokens + other.cached_tokens,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct Request {
    pub model: Option<String>,
    pub messages: Vec<Message>,
    pub tools: Vec<ToolSpec>,
    pub tool_choice: Option<String>,
    pub response_format: Option<ResponseFormat>,
    pub cache_hint: Option<CacheHint>,
    pub temperature: f64,
}

impl Request {
    pub fn of(messages: Vec<Message>) -> Self {
        Self {
            messages,
            ..Self::default()
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResponseFormat {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub schema: Option<Map<String, Value>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CacheHint {
    #[serde(rename = "stablePrefix", default)]
    pub stable_prefix: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ttl: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct Response {
    pub message: Message,
    pub usage: Usage,
    pub finish_reason: Option<String>,
}

impl Default for Message {
    fn default() -> Self {
        Self {
            role: ROLE_ASSISTANT.to_string(),
            content: None,
            content_blocks: Vec::new(),
            tool_calls: Vec::new(),
            tool_id: None,
        }
    }
}

pub trait Model: Send + Sync {
    fn generate(&self, request: &Request) -> Result<Response>;
}

pub trait StreamingModel: Model {
    fn generate_stream(
        &self,
        request: &Request,
        on_delta: &mut dyn FnMut(&str),
    ) -> Result<Response>;
}
