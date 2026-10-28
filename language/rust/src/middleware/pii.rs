use std::sync::OnceLock;

use regex::Regex;
use serde_json::{Map, Value};

use crate::errors::Result;
use crate::middleware::{Middleware, MiddlewareToolCall, ModelCall, ToolResult};
use crate::model::{ContentBlock, Message, Request, ToolCall};

pub struct PiiRule {
    pub name: String,
    pub pattern: Regex,
    pub replacement: String,
}

impl PiiRule {
    pub fn new(name: &str, pattern: &str, replacement: &str) -> Self {
        Self {
            name: name.to_string(),
            pattern: Regex::new(pattern).expect("valid regex"),
            replacement: replacement.to_string(),
        }
    }
}

pub fn default_pii_rules() -> Vec<PiiRule> {
    vec![
        PiiRule::new(
            "email",
            r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}",
            "[REDACTED:email]",
        ),
        PiiRule::new("ssn", r"\b\d{3}-\d{2}-\d{4}\b", "[REDACTED:ssn]"),
        PiiRule::new(
            "credit_card",
            r"\b(?:\d{4}[ -]?){3}\d{4}\b",
            "[REDACTED:credit_card]",
        ),
        PiiRule::new(
            "phone",
            r"\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b",
            "[REDACTED:phone]",
        ),
    ]
}

pub struct PiiRedactor {
    rules: Vec<PiiRule>,
}

impl PiiRedactor {
    pub fn new(rules: Vec<PiiRule>) -> Self {
        Self { rules }
    }

    pub fn defaults() -> Self {
        Self::new(default_pii_rules())
    }

    pub fn redact(&self, text: &str) -> String {
        let mut out = text.to_string();
        for rule in &self.rules {
            let replacement = if rule.replacement.is_empty() {
                "[REDACTED]"
            } else {
                &rule.replacement
            };
            out = rule.pattern.replace_all(&out, replacement).to_string();
        }
        out
    }

    pub fn redact_value(&self, value: &Value) -> Value {
        match value {
            Value::String(text) => Value::String(self.redact(text)),
            Value::Array(items) => {
                Value::Array(items.iter().map(|item| self.redact_value(item)).collect())
            }
            Value::Object(map) => {
                let mut out = Map::new();
                for (key, item) in map {
                    out.insert(key.clone(), self.redact_value(item));
                }
                Value::Object(out)
            }
            other => other.clone(),
        }
    }
}

pub struct PiiMiddleware {
    redactor: PiiRedactor,
}

impl PiiMiddleware {
    pub fn new(redactor: PiiRedactor) -> Self {
        Self { redactor }
    }
}

impl Middleware for PiiMiddleware {
    fn name(&self) -> &str {
        "pii"
    }

    fn before_model(&self, call: &mut ModelCall) -> Result<()> {
        let messages = call
            .request
            .messages
            .iter()
            .map(|message| Message {
                role: message.role.clone(),
                content: Some(self.redactor.redact(message.content.as_deref().unwrap_or(""))),
                content_blocks: message
                    .content_blocks
                    .iter()
                    .map(|block| ContentBlock {
                        kind: block.kind.clone(),
                        text: Some(self.redactor.redact(block.text.as_deref().unwrap_or(""))),
                        image_url: block.image_url.clone(),
                        data: block.data.clone(),
                    })
                    .collect(),
                tool_calls: message
                    .tool_calls
                    .iter()
                    .map(|tool_call| ToolCall {
                        id: tool_call.id.clone(),
                        name: tool_call.name.clone(),
                        arguments: tool_call
                            .arguments
                            .iter()
                            .map(|(key, value)| {
                                (key.clone(), self.redactor.redact_value(value))
                            })
                            .collect(),
                    })
                    .collect(),
                tool_id: message.tool_id.clone(),
            })
            .collect();
        call.request = Request {
            messages,
            ..call.request.clone()
        };
        Ok(())
    }

    fn after_tool(
        &self,
        _call: &MiddlewareToolCall,
        result: &mut ToolResult,
    ) -> Result<()> {
        result.value = self.redactor.redact_value(&result.value);
        Ok(())
    }
}

fn _unused() {
    let _ = OnceLock::<Regex>::new();
}
