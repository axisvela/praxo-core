use std::fs;
use std::sync::Arc;

use crate::errors::{PraxoError, Result};
use crate::model::{Message, Model, Request, ROLE_SYSTEM, ROLE_TOOL};

pub const MAX_AGENTS_MD_BYTES: usize = 64 << 10;
pub const COMPACT_MARKER_PREFIX: &str = "[context compacted:";
pub const SUMMARY_MARKER_PREFIX: &str = "[context summary:";
pub const DEFAULT_SUMMARY_PROMPT: &str =
    "Summarize the conversation so far. Preserve decisions, open tasks, \
     tool results, constraints, and user preferences. Be concise.";

fn byte_len(value: Option<&str>) -> usize {
    value.map(|text| text.len()).unwrap_or(0)
}

pub fn estimate_tokens(messages: &[Message]) -> usize {
    let mut total = 0;
    for message in messages {
        total += 4
            + byte_len(message.content.as_deref()) / 4
            + byte_len(message.tool_id.as_deref()) / 4;
        for block in &message.content_blocks {
            total += 4
                + byte_len(block.text.as_deref()) / 4
                + byte_len(block.image_url.as_deref()) / 4
                + byte_len(block.data.as_deref()) / 4;
        }
        for call in &message.tool_calls {
            total += 4 + call.name.len() / 4;
            if let Ok(raw) = serde_json::to_string(&call.arguments) {
                total += raw.len() / 4;
            }
        }
    }
    total
}

pub fn truncate_to_tokens(value: &str, tokens: usize) -> String {
    if tokens == 0 {
        return String::new();
    }
    let limit = tokens * 4;
    let raw = value.as_bytes();
    if raw.len() <= limit {
        return value.to_string();
    }
    if limit <= 16 {
        return String::from_utf8_lossy(&raw[..limit]).to_string();
    }
    format!(
        "{}\n[truncated]",
        String::from_utf8_lossy(&raw[..limit - 16])
    )
}

#[derive(Debug, Clone, Copy)]
pub struct ContextBudget {
    pub max_tokens: usize,
    pub keep_recent: usize,
}

impl ContextBudget {
    pub fn new(max_tokens: usize, keep_recent: usize) -> Self {
        Self {
            max_tokens,
            keep_recent,
        }
    }

    pub fn compact(&self, messages: &[Message]) -> (Vec<Message>, bool) {
        if self.max_tokens == 0 || estimate_tokens(messages) <= self.max_tokens {
            return (messages.to_vec(), true);
        }
        let mut system = Vec::new();
        let mut rest = Vec::new();
        for message in messages {
            if message.role == ROLE_SYSTEM {
                if message
                    .content
                    .as_deref()
                    .unwrap_or("")
                    .starts_with(COMPACT_MARKER_PREFIX)
                {
                    continue;
                }
                system.push(message.clone());
            } else {
                rest.push(message.clone());
            }
        }
        if estimate_tokens(&system) > self.max_tokens {
            let Some(first) = system.first().cloned() else {
                return (Vec::new(), false);
            };
            let mut truncated = first;
            truncated.content = Some(truncate_to_tokens(
                truncated.content.as_deref().unwrap_or(""),
                self.max_tokens.saturating_sub(4),
            ));
            system = vec![truncated];
            if estimate_tokens(&system) > self.max_tokens {
                return (Vec::new(), false);
            }
        }
        let keep = if self.keep_recent > 0 { self.keep_recent } else { 4 };
        let mut start = rest.len().saturating_sub(keep);
        while start > 0 && rest[start].role == ROLE_TOOL {
            start -= 1;
        }
        let marker = Message::text(
            ROLE_SYSTEM,
            format!("{COMPACT_MARKER_PREFIX} {start} older messages omitted]"),
        );
        let mut kept: Vec<Message> = rest[start..].to_vec();
        let mut out = build(&system, &marker, start > 0, &kept);
        while estimate_tokens(&out) > self.max_tokens && kept.len() > 1 {
            if kept[1].role == ROLE_TOOL {
                break;
            }
            kept.remove(0);
            out = build(&system, &marker, start > 0, &kept);
        }
        if estimate_tokens(&out) > self.max_tokens {
            return (Vec::new(), false);
        }
        (out, true)
    }
}

fn build(
    system: &[Message],
    marker: &Message,
    include_marker: bool,
    kept: &[Message],
) -> Vec<Message> {
    let mut out = system.to_vec();
    if include_marker {
        out.push(marker.clone());
    }
    out.extend_from_slice(kept);
    out
}

pub trait ContextCompactor: Send + Sync {
    fn compact(&self, messages: &[Message], budget: &ContextBudget) -> Result<Vec<Message>>;
}

pub struct ModelSummarizer {
    model: Option<Arc<dyn Model>>,
    prompt: String,
    max_summary_tokens: usize,
}

impl ModelSummarizer {
    pub fn new(model: Option<Arc<dyn Model>>) -> Self {
        Self {
            model,
            prompt: String::new(),
            max_summary_tokens: 0,
        }
    }

    pub fn with_prompt(mut self, prompt: impl Into<String>, max_summary_tokens: usize) -> Self {
        self.prompt = prompt.into();
        self.max_summary_tokens = max_summary_tokens;
        self
    }
}

impl ContextCompactor for ModelSummarizer {
    fn compact(&self, messages: &[Message], budget: &ContextBudget) -> Result<Vec<Message>> {
        if budget.max_tokens == 0 || estimate_tokens(messages) <= budget.max_tokens {
            return Ok(messages.to_vec());
        }
        let Some(model) = &self.model else {
            return fit_budget(messages, budget);
        };
        let mut system = Vec::new();
        let mut rest = Vec::new();
        for message in messages {
            if message.role == ROLE_SYSTEM {
                let content = message.content.as_deref().unwrap_or("");
                if content.starts_with(COMPACT_MARKER_PREFIX)
                    || content.starts_with(SUMMARY_MARKER_PREFIX)
                {
                    continue;
                }
                system.push(message.clone());
            } else {
                rest.push(message.clone());
            }
        }
        let keep = if budget.keep_recent > 0 { budget.keep_recent } else { 4 };
        let mut start = rest.len().saturating_sub(keep);
        while start > 0 && rest[start].role == ROLE_TOOL {
            start -= 1;
        }
        if start == 0 {
            return fit_budget(messages, budget);
        }
        let prompt = if self.prompt.trim().is_empty() {
            DEFAULT_SUMMARY_PROMPT.to_string()
        } else {
            self.prompt.clone()
        };
        let mut request_messages = vec![Message::text(ROLE_SYSTEM, prompt)];
        request_messages.extend_from_slice(&rest[..start]);
        let summary = match model.generate(&Request::of(request_messages)) {
            Ok(response) => response.message.content.unwrap_or_default(),
            Err(_) => return fit_budget(messages, budget),
        };
        if summary.trim().is_empty() {
            return fit_budget(messages, budget);
        }
        let max_summary = if self.max_summary_tokens > 0 {
            self.max_summary_tokens
        } else {
            budget.max_tokens / 4
        };
        let trimmed = truncate_to_tokens(summary.trim(), max_summary);
        let mut out = system;
        out.push(Message::text(
            ROLE_SYSTEM,
            format!("{SUMMARY_MARKER_PREFIX} {trimmed}]"),
        ));
        out.extend_from_slice(&rest[start..]);
        fit_budget(&out, budget)
    }
}

fn fit_budget(messages: &[Message], budget: &ContextBudget) -> Result<Vec<Message>> {
    let (out, ok) = budget.compact(messages);
    if !ok {
        return Err(PraxoError::context_budget());
    }
    Ok(out)
}

pub trait Offloader: Send + Sync {
    fn offload(&self, tool_name: &str, tool_call_id: &str, data: &[u8]) -> Result<String>;
}

pub struct OffloadFunc<F>
where
    F: Fn(&str, &str, &[u8]) -> Result<String> + Send + Sync,
{
    function: F,
}

impl<F> OffloadFunc<F>
where
    F: Fn(&str, &str, &[u8]) -> Result<String> + Send + Sync,
{
    pub fn new(function: F) -> Self {
        Self { function }
    }
}

impl<F> Offloader for OffloadFunc<F>
where
    F: Fn(&str, &str, &[u8]) -> Result<String> + Send + Sync,
{
    fn offload(&self, tool_name: &str, tool_call_id: &str, data: &[u8]) -> Result<String> {
        (self.function)(tool_name, tool_call_id, data)
    }
}

pub fn load_agents_md(paths: &[String]) -> Result<String> {
    let mut out = String::new();
    let mut used = 0;
    for path in paths {
        if path.trim().is_empty() {
            continue;
        }
        let text = fs::read_to_string(path).map_err(|error| {
            PraxoError::new(
                "AGENT_MEMORY",
                format!("agent: read AGENTS.md {path}: {error}"),
            )
        })?;
        let text = text.trim();
        if text.is_empty() {
            continue;
        }
        let header = format!("## AGENTS.md: {path}\n");
        let chunk = format!("{header}{text}");
        if used + chunk.len() > MAX_AGENTS_MD_BYTES {
            let remaining = MAX_AGENTS_MD_BYTES.saturating_sub(used);
            if remaining <= header.len() {
                break;
            }
            if !out.is_empty() {
                out.push_str("\n\n");
            }
            out.push_str(&String::from_utf8_lossy(&chunk.as_bytes()[..remaining]));
            out.push_str("\n[truncated]");
            break;
        }
        if !out.is_empty() {
            out.push_str("\n\n");
        }
        out.push_str(&chunk);
        used += chunk.len();
    }
    Ok(out)
}
