use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};

use serde_json::Value;

use crate::agent::RunResult;
use crate::errors::{PraxoError, Result};
use crate::middleware::structured::extract_json;
use crate::middleware::{Middleware, MiddlewareToolCall, ModelCall};
use crate::model::{Message, Model, Request, ToolSpec, ROLE_SYSTEM, ROLE_USER};

pub const DEFAULT_TOOL_SELECTOR_PROMPT: &str =
    "Select the tools needed to answer the user query.\n\
     Return only JSON in the form {\"tools\":[\"tool_name\"]}.\n\
     Prefer the smallest sufficient set. Return {\"tools\":[]} when no tool is needed.";

pub trait ToolSelector: Send + Sync {
    fn select(&self, query: &str, tools: &[ToolSpec]) -> Result<Vec<String>>;
}

pub struct ToolSelectionMiddleware {
    selector: Arc<dyn ToolSelector>,
    selected: Mutex<HashMap<String, HashSet<String>>>,
}

impl ToolSelectionMiddleware {
    pub fn new(selector: Arc<dyn ToolSelector>) -> Self {
        Self {
            selector,
            selected: Mutex::new(HashMap::new()),
        }
    }
}

impl Middleware for ToolSelectionMiddleware {
    fn name(&self) -> &str {
        "tool-selection"
    }

    fn before_model(&self, call: &mut ModelCall) -> Result<()> {
        let names = self
            .selector
            .select(last_user_message(&call.request.messages), &call.request.tools)?;
        let chosen: HashSet<String> = names.into_iter().collect();
        self.selected
            .lock()
            .expect("tool selection poisoned")
            .insert(call.run_id.clone(), chosen.clone());
        call.request.tools = call
            .request
            .tools
            .iter()
            .filter(|spec| chosen.contains(&spec.name))
            .cloned()
            .collect();
        Ok(())
    }

    fn before_tool(&self, call: &mut MiddlewareToolCall) -> Result<()> {
        let selected = self.selected.lock().expect("tool selection poisoned");
        if let Some(chosen) = selected.get(&call.run_id) {
            if !chosen.contains(&call.call.name) {
                return Err(PraxoError::tool_not_selected());
            }
        }
        Ok(())
    }

    fn after_run(
        &self,
        result: Option<&mut RunResult>,
        _error: Option<&PraxoError>,
    ) -> Result<()> {
        if let Some(result) = result {
            self.selected
                .lock()
                .expect("tool selection poisoned")
                .remove(&result.run_id);
        }
        Ok(())
    }
}

pub fn last_user_message(messages: &[Message]) -> &str {
    for message in messages.iter().rev() {
        if message.role == ROLE_USER {
            return message.content.as_deref().unwrap_or("");
        }
    }
    ""
}

pub struct ModelToolSelector {
    model: Option<Arc<dyn Model>>,
    prompt: String,
    max_tools: usize,
}

impl ModelToolSelector {
    pub fn new(model: Option<Arc<dyn Model>>) -> Self {
        Self {
            model,
            prompt: String::new(),
            max_tools: 0,
        }
    }

    pub fn with_prompt(mut self, prompt: impl Into<String>, max_tools: usize) -> Self {
        self.prompt = prompt.into();
        self.max_tools = max_tools;
        self
    }
}

impl ToolSelector for ModelToolSelector {
    fn select(&self, query: &str, tools: &[ToolSpec]) -> Result<Vec<String>> {
        let Some(model) = &self.model else {
            return Err(PraxoError::new(
                "TOOL_SELECTOR_MODEL",
                "agent: tool selector model is required",
            ));
        };
        if tools.is_empty() {
            return Ok(Vec::new());
        }
        let prompt: &str = if self.prompt.trim().is_empty() {
            DEFAULT_TOOL_SELECTOR_PROMPT
        } else {
            self.prompt.as_str()
        };
        let catalog = tools
            .iter()
            .map(|spec| format!("\n- {}: {}", spec.name, spec.description))
            .collect::<String>();
        let request = Request::of(vec![
            Message::text(ROLE_SYSTEM, prompt),
            Message::text(
                ROLE_USER,
                format!("Query: {query}\nAvailable tools:{catalog}"),
            ),
        ]);
        let response = model.generate(&request)?;
        let parsed = extract_json(response.message.content.as_deref().unwrap_or(""))?;
        let requested = parsed
            .get("tools")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let known: HashSet<String> = tools.iter().map(|spec| spec.name.clone()).collect();
        let mut seen = HashSet::new();
        let mut out = Vec::new();
        for name in requested {
            let Some(name) = name.as_str() else {
                continue;
            };
            if !known.contains(name) || !seen.insert(name.to_string()) {
                continue;
            }
            out.push(name.to_string());
            if self.max_tools > 0 && out.len() >= self.max_tools {
                break;
            }
        }
        Ok(out)
    }
}
