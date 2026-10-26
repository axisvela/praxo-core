use std::sync::Arc;

use serde_json::{Map, Value};

use crate::context::{load_agents_md, ContextBudget, ContextCompactor, Offloader};
use crate::errors::{PraxoError, Result};
use crate::event::{now_iso, Event, Sink};
use crate::middleware::{
    fallback_model, merge_middleware, CallLimitMiddleware, Middleware, MiddlewareToolCall,
    ModelCall, ModelHandler, ModelMiddleware, PiiMiddleware, PiiRedactor, RunState,
    StructuredOutput, ToolResult, ToolSelectionMiddleware, ToolSelector,
};
use crate::model::{
    Message, Model, Request, Response, ResponseFormat, ToolCall, ToolSpec, Usage, ROLE_SYSTEM,
    ROLE_USER,
};
use crate::policy::{Action, Hook};
use crate::tool::Registry;

pub struct Session {
    pub id: String,
    pub tenant_id: String,
    pub workspace_id: String,
    pub messages: Vec<Message>,
}

impl Session {
    pub fn new(id: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            tenant_id: "default".to_string(),
            workspace_id: String::new(),
            messages: Vec::new(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct RunResult {
    pub run_id: String,
    pub output: String,
    pub steps: usize,
    pub usage: Usage,
}

pub struct AgentOptions {
    pub model: Arc<dyn Model>,
    pub tools: Option<Arc<Registry>>,
    pub events: Option<Arc<dyn Sink>>,
    pub policy: Option<Arc<dyn Hook>>,
    pub system_prompt: String,
    pub memory_files: Vec<String>,
    pub context: Option<ContextBudget>,
    pub compactor: Option<Arc<dyn ContextCompactor>>,
    pub offloader: Option<Arc<dyn Offloader>>,
    pub offload_threshold_bytes: usize,
    pub middleware: Vec<Box<dyn Middleware>>,
    pub model_middleware: Vec<ModelMiddleware>,
    pub structured_output: Option<StructuredOutput>,
    pub allowed_tools: Vec<String>,
    pub tool_selector: Option<Arc<dyn ToolSelector>>,
    pub pii_redactor: Option<PiiRedactor>,
    pub model_call_limit: usize,
    pub tool_call_limit: usize,
    pub fallback_model: Option<Arc<dyn Model>>,
    pub tool_choice: Option<String>,
    pub response_format: Option<ResponseFormat>,
    pub max_steps: usize,
    pub max_tokens: i64,
}

impl AgentOptions {
    pub fn new(model: Arc<dyn Model>) -> Self {
        Self {
            model,
            tools: None,
            events: None,
            policy: None,
            system_prompt: String::new(),
            memory_files: Vec::new(),
            context: None,
            compactor: None,
            offloader: None,
            offload_threshold_bytes: 0,
            middleware: Vec::new(),
            model_middleware: Vec::new(),
            structured_output: None,
            allowed_tools: Vec::new(),
            tool_selector: None,
            pii_redactor: None,
            model_call_limit: 0,
            tool_call_limit: 0,
            fallback_model: None,
            tool_choice: None,
            response_format: None,
            max_steps: 8,
            max_tokens: 0,
        }
    }
}

pub struct Agent {
    options: AgentOptions,
    system_prompt: String,
    middleware: Vec<Box<dyn Middleware>>,
    model_middleware: Vec<ModelMiddleware>,
}

impl Agent {
    pub fn new(mut options: AgentOptions) -> Result<Self> {
        let memory = load_agents_md(&options.memory_files)?;
        let system_prompt = if memory.is_empty() {
            options.system_prompt.clone()
        } else {
            format!("{}\n\n{}", options.system_prompt, memory).trim().to_string()
        };
        let mut middleware = std::mem::take(&mut options.middleware);
        if let Some(structured) = options.structured_output.take() {
            middleware.push(Box::new(structured));
        }
        if let Some(selector) = options.tool_selector.take() {
            middleware.push(Box::new(ToolSelectionMiddleware::new(selector)));
        }
        if let Some(redactor) = options.pii_redactor.take() {
            middleware.push(Box::new(PiiMiddleware::new(redactor)));
        }
        if options.model_call_limit > 0 || options.tool_call_limit > 0 {
            middleware.push(Box::new(CallLimitMiddleware::new(
                options.model_call_limit,
                options.tool_call_limit,
            )));
        }
        let mut model_middleware = std::mem::take(&mut options.model_middleware);
        if let Some(fallback) = options.fallback_model.take() {
            model_middleware.push(fallback_model(Some(fallback)));
        }
        Ok(Self {
            options,
            system_prompt,
            middleware: merge_middleware(middleware),
            model_middleware,
        })
    }

    pub fn run(&self, session: &Session, prompt: &str) -> Result<RunResult> {
        let max_steps = if self.options.max_steps > 0 {
            self.options.max_steps
        } else {
            8
        };
        let run_id = format!(
            "run-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
        );
        let mut messages = session.messages.clone();
        if !self.system_prompt.is_empty() {
            messages.insert(0, Message::text(ROLE_SYSTEM, self.system_prompt.clone()));
        }
        messages.push(Message::text(ROLE_USER, prompt));
        let mut usage = Usage::default();

        self.before_run(&run_id, prompt)?;
        self.emit("run.started", &session.id, &run_id, None)?;
        let mut after_run_invoked = false;
        let outcome = (|| -> Result<RunResult> {
            for step in 1..=max_steps {
                self.authorize(&Action {
                    kind: "model.generate".to_string(),
                    session_id: session.id.clone(),
                    tool_name: None,
                    arguments: None,
                })?;
                messages = self.compact(&messages)?;
                let request = Request {
                    messages: messages.clone(),
                    tools: self.tool_specs(),
                    tool_choice: self.options.tool_choice.clone(),
                    response_format: self.options.response_format.clone(),
                    ..Request::default()
                };
                let mut call = ModelCall {
                    run_id: run_id.clone(),
                    session_id: session.id.clone(),
                    request,
                    skip: false,
                    response: None,
                };
                self.before_model(&mut call)?;
                let response = if call.skip {
                    call.response.take().ok_or_else(|| {
                        PraxoError::new(
                            "AGENT_MIDDLEWARE",
                            "agent: model middleware skipped without a response",
                        )
                    })?
                } else {
                    self.generate(&call.request)?
                };
                self.after_model(&call, &response)?;
                usage = usage.plus(response.usage);
                if self.options.max_tokens > 0
                    && usage.input_tokens + usage.output_tokens > self.options.max_tokens
                {
                    return Err(PraxoError::max_tokens());
                }
                messages.push(response.message.clone());
                if response.message.tool_calls.is_empty() {
                    let mut result = RunResult {
                        run_id: run_id.clone(),
                        output: response.message.content.unwrap_or_default(),
                        steps: step,
                        usage,
                    };
                    after_run_invoked = true;
                    self.after_run(Some(&mut result), None)?;
                    self.emit("run.completed", &session.id, &run_id, None)?;
                    return Ok(result);
                }
                for tool_call in response.message.tool_calls {
                    messages.push(self.invoke_tool(&tool_call, &run_id, &session.id)?);
                }
            }
            Err(PraxoError::max_steps())
        })();

        match outcome {
            Ok(result) => Ok(result),
            Err(error) => {
                if !after_run_invoked {
                    let _ = self.after_run(None, Some(&error));
                }
                let mut data = Map::new();
                data.insert("error".to_string(), Value::String(error.message.clone()));
                let _ = self.emit("run.failed", &session.id, &run_id, Some(data));
                Err(error)
            }
        }
    }

    fn compact(&self, messages: &[Message]) -> Result<Vec<Message>> {
        let Some(budget) = self.options.context else {
            return Ok(messages.to_vec());
        };
        if budget.max_tokens == 0 {
            return Ok(messages.to_vec());
        }
        let mut current = messages.to_vec();
        if let Some(compactor) = &self.options.compactor {
            if crate::context::estimate_tokens(&current) > budget.max_tokens {
                current = compactor.compact(&current, &budget)?;
            }
        }
        let (out, ok) = budget.compact(&current);
        if !ok {
            return Err(PraxoError::context_budget());
        }
        Ok(out)
    }

    fn tool_specs(&self) -> Vec<ToolSpec> {
        let Some(tools) = &self.options.tools else {
            return Vec::new();
        };
        let specs = tools.specs();
        if self.options.allowed_tools.is_empty() {
            return specs;
        }
        specs
            .into_iter()
            .filter(|spec| self.options.allowed_tools.contains(&spec.name))
            .collect()
    }

    fn tool_allowed(&self, name: &str) -> bool {
        self.options.allowed_tools.is_empty()
            || self.options.allowed_tools.iter().any(|item| item == name)
    }

    fn generate(&self, request: &Request) -> Result<Response> {
        let model = self.options.model.clone();
        let mut handler: ModelHandler = Box::new(move |req| model.generate(req));
        for middleware in self.model_middleware.iter().rev() {
            handler = middleware(handler);
        }
        handler(request)
    }

    fn invoke_tool(
        &self,
        call: &ToolCall,
        run_id: &str,
        session_id: &str,
    ) -> Result<Message> {
        if !self.tool_allowed(&call.name) {
            return Err(PraxoError::new(
                "AGENT_TOOL_NOT_ALLOWED",
                format!("agent: tool {} is not allowed", call.name),
            ));
        }
        self.authorize(&Action {
            kind: "tool.invoke".to_string(),
            session_id: session_id.to_string(),
            tool_name: Some(call.name.clone()),
            arguments: Some(call.arguments.clone()),
        })?;
        let tools = self.options.tools.as_ref().ok_or_else(|| {
            PraxoError::tool_not_found(format!("tool {} is not registered", call.name))
        })?;
        let tool = tools.get(&call.name)?;
        let mut middleware_call = MiddlewareToolCall {
            run_id: run_id.to_string(),
            session_id: session_id.to_string(),
            call: call.clone(),
            skip: false,
            result: None,
            error: None,
        };
        self.before_tool(&mut middleware_call)?;
        let active = middleware_call.call.clone();
        let (value, error) = if middleware_call.skip {
            (
                middleware_call.result.take().unwrap_or(Value::Null),
                middleware_call.error.take(),
            )
        } else {
            let mut data = Map::new();
            data.insert("name".to_string(), Value::String(active.name.clone()));
            data.insert("arguments".to_string(), Value::Object(active.arguments.clone()));
            self.emit("tool.call", session_id, run_id, Some(data))?;
            match tool.invoke(&active.arguments) {
                Ok(value) => (value, None),
                Err(error) => (Value::Null, Some(error)),
            }
        };
        let mut result = ToolResult { value, error };
        self.after_tool(&middleware_call, &mut result)?;
        if let Some(error) = result.error {
            return Err(error);
        }
        let mut content = serde_json::to_string(&result.value)
            .map_err(|error| PraxoError::new("TOOL_RESULT", error.to_string()))?;
        let raw = content.as_bytes();
        if let Some(offloader) = &self.options.offloader {
            if self.options.offload_threshold_bytes > 0
                && raw.len() > self.options.offload_threshold_bytes
            {
                let reference = offloader.offload(&active.name, &active.id, raw)?;
                if reference.is_empty() {
                    return Err(PraxoError::new(
                        "AGENT_OFFLOAD",
                        "agent: offloader returned an empty placeholder",
                    ));
                }
                content = reference;
            }
        }
        Ok(Message::tool(content, active.id))
    }

    fn before_run(&self, run_id: &str, prompt: &str) -> Result<()> {
        let state = RunState {
            run_id: run_id.to_string(),
            prompt: prompt.to_string(),
        };
        for middleware in &self.middleware {
            middleware.before_run(&state)?;
        }
        Ok(())
    }

    fn before_model(&self, call: &mut ModelCall) -> Result<()> {
        for middleware in &self.middleware {
            middleware.before_model(call)?;
            if call.skip {
                break;
            }
        }
        Ok(())
    }

    fn after_model(&self, call: &ModelCall, response: &Response) -> Result<()> {
        for middleware in &self.middleware {
            middleware.after_model(call, response)?;
        }
        Ok(())
    }

    fn before_tool(&self, call: &mut MiddlewareToolCall) -> Result<()> {
        for middleware in &self.middleware {
            middleware.before_tool(call)?;
            if call.skip {
                break;
            }
        }
        Ok(())
    }

    fn after_tool(&self, call: &MiddlewareToolCall, result: &mut ToolResult) -> Result<()> {
        for middleware in &self.middleware {
            middleware.after_tool(call, result)?;
        }
        Ok(())
    }

    fn after_run(
        &self,
        mut result: Option<&mut RunResult>,
        error: Option<&PraxoError>,
    ) -> Result<()> {
        for middleware in &self.middleware {
            middleware.after_run(result.as_deref_mut(), error)?;
        }
        Ok(())
    }

    fn authorize(&self, action: &Action) -> Result<()> {
        let Some(policy) = &self.options.policy else {
            return Ok(());
        };
        let decision = policy.authorize(action)?;
        if !decision.allowed {
            return Err(PraxoError::new(
                "AGENT_POLICY_DENIED",
                format!("agent: {} denied: {}", action.kind, decision.reason),
            ));
        }
        Ok(())
    }

    fn emit(
        &self,
        kind: &str,
        session_id: &str,
        run_id: &str,
        data: Option<Map<String, Value>>,
    ) -> Result<()> {
        let Some(events) = &self.options.events else {
            return Ok(());
        };
        let event = Event {
            kind: kind.to_string(),
            session_id: session_id.to_string(),
            run_id: Some(run_id.to_string()),
            data,
            at: Some(now_iso()),
        };
        events.emit(&event)
    }
}


