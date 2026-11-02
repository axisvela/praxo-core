use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use serde_json::{Map, Value};

use crate::context::{load_agents_md, ContextBudget, ContextCompactor, Offloader};
use crate::errors::{PraxoError, Result};
use crate::event::{now_iso, Event, Sink};
use crate::hitl::{Interrupt, InterruptAction, InterruptApproval, InterruptHandler};
use crate::middleware::{
    fallback_model, merge_middleware, CallLimitMiddleware, Middleware, MiddlewareToolCall,
    ModelCall, ModelHandler, ModelMiddleware, PiiMiddleware, PiiRedactor, RunState,
    StructuredOutput, ToolResult, ToolSelectionMiddleware, ToolSelector,
};
use crate::model::{
    Message, Model, Request, Response, ResponseFormat, StreamingModel, ToolCall, ToolSpec, Usage,
    ROLE_SYSTEM, ROLE_USER,
};
use crate::policy::{Action, Hook};
use crate::tool::{Registry, Tool};

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

#[derive(Clone, Default)]
pub struct CancellationToken {
    inner: Arc<AtomicBool>,
}

impl CancellationToken {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn cancel(&self) {
        self.inner.store(true, Ordering::SeqCst);
    }

    pub fn is_cancelled(&self) -> bool {
        self.inner.load(Ordering::SeqCst)
    }
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
    pub max_parallel_tools: usize,
    pub cancellation: Option<CancellationToken>,
    pub streaming_model: Option<Arc<dyn StreamingModel>>,
    pub max_tokens: i64,
    pub interrupt_on: Vec<String>,
    pub on_interrupt_decision: Option<InterruptHandler>,
    pub on_interrupt: Option<InterruptApproval>,
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
            max_parallel_tools: 0,
            cancellation: None,
            streaming_model: None,
            max_tokens: 0,
            interrupt_on: Vec::new(),
            on_interrupt_decision: None,
            on_interrupt: None,
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
        self.run_internal(session, prompt, None)
    }

    pub fn run_stream(
        &self,
        session: &Session,
        prompt: &str,
        on_delta: &mut dyn FnMut(&str) -> Result<()>,
    ) -> Result<RunResult> {
        self.run_internal(session, prompt, Some(on_delta))
    }

    fn run_internal(
        &self,
        session: &Session,
        prompt: &str,
        mut on_delta: Option<&mut dyn FnMut(&str) -> Result<()>>,
    ) -> Result<RunResult> {
        self.throw_if_cancelled()?;
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

        let mut entered = Vec::new();
        if let Err(error) = self.before_run(&run_id, prompt, &mut entered) {
            let _ = self.after_run_entered(&entered, None, Some(&error));
            return Err(error);
        }
        self.emit("run.started", &session.id, &run_id, None)?;
        let mut after_run_invoked = false;
        let outcome = (|| -> Result<RunResult> {
            for step in 1..=max_steps {
                self.throw_if_cancelled()?;
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
                } else if let Some(callback) = on_delta.as_deref_mut() {
                    let streaming = self
                        .options
                        .streaming_model
                        .as_deref()
                        .ok_or_else(|| {
                            PraxoError::new(
                                "AGENT_STREAM",
                                "agent: model does not support streaming",
                            )
                        })?;
                    streaming.generate_stream(&call.request, callback)?
                } else {
                    self.generate(&call.request)?
                };
                self.throw_if_cancelled()?;
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
                    if let Some(error) = self.after_run_entered(
                        &entered,
                        Some(&mut result),
                        None,
                    ) {
                        return Err(error);
                    }
                    self.emit("run.completed", &session.id, &run_id, None)?;
                    return Ok(result);
                }
                messages.extend(self.invoke_tools(
                    &response.message.tool_calls,
                    &run_id,
                    &session.id,
                )?);
            }
            Err(PraxoError::max_steps())
        })();

        match outcome {
            Ok(result) => Ok(result),
            Err(error) => {
                if !after_run_invoked {
                    let _ = self.after_run_entered(&entered, None, Some(&error));
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

    fn invoke_tools(
        &self,
        calls: &[ToolCall],
        run_id: &str,
        session_id: &str,
    ) -> Result<Vec<Message>> {
        if self.options.max_parallel_tools <= 1 || calls.len() <= 1 {
            let mut out = Vec::new();
            for call in calls {
                out.push(self.invoke_tool(call, run_id, session_id)?);
            }
            return Ok(out);
        }
        let mut prepared = Vec::new();
        for call in calls {
            prepared.push(self.prepare_tool(call, run_id, session_id)?);
        }
        let workers = self.options.max_parallel_tools.min(prepared.len());
        let next = AtomicUsize::new(0);
        let results: Mutex<Vec<Option<ToolResult>>> =
            Mutex::new((0..prepared.len()).map(|_| None).collect());
        std::thread::scope(|scope| {
            for _ in 0..workers {
                scope.spawn(|| loop {
                    let index = next.fetch_add(1, Ordering::SeqCst);
                    if index >= prepared.len() {
                        break;
                    }
                    let result = self.execute_prepared(&prepared[index]);
                    results.lock().expect("tool results")[index] = Some(result);
                });
            }
        });
        let mut out = Vec::new();
        for (index, item) in prepared.iter().enumerate() {
            let result = results
                .lock()
                .expect("tool results")
                .get_mut(index)
                .and_then(Option::take)
                .expect("tool result");
            out.push(self.finish_tool(item, result)?);
        }
        Ok(out)
    }

    fn invoke_tool(
        &self,
        call: &ToolCall,
        run_id: &str,
        session_id: &str,
    ) -> Result<Message> {
        let prepared = self.prepare_tool(call, run_id, session_id)?;
        let result = self.execute_prepared(&prepared);
        self.finish_tool(&prepared, result)
    }

    fn prepare_tool(
        &self,
        call: &ToolCall,
        run_id: &str,
        session_id: &str,
    ) -> Result<PreparedTool> {
        self.throw_if_cancelled()?;
        let original_name = call.name.clone();
        let original_arguments = call.arguments.clone();
        if !self.tool_allowed(&original_name) {
            return Err(PraxoError::new(
                "AGENT_TOOL_NOT_ALLOWED",
                format!("agent: tool {original_name} is not allowed"),
            ));
        }
        self.authorize(&Action {
            kind: "tool.invoke".to_string(),
            session_id: session_id.to_string(),
            tool_name: Some(original_name.clone()),
            arguments: Some(original_arguments.clone()),
        })?;
        let mut middleware_call = MiddlewareToolCall {
            run_id: run_id.to_string(),
            session_id: session_id.to_string(),
            call: call.clone(),
            skip: false,
            result: None,
            error: None,
        };
        self.before_tool(&mut middleware_call)?;
        let mut active = middleware_call.call.clone();
        if !self.tool_allowed(&active.name) {
            return Err(PraxoError::new(
                "AGENT_TOOL_NOT_ALLOWED",
                format!("agent: tool {} is not allowed", active.name),
            ));
        }
        if middleware_call.skip {
            let value = middleware_call.result.take().unwrap_or(Value::Null);
            let error = middleware_call.error.take();
            return Ok(PreparedTool {
                middleware_call,
                active,
                tool: None,
                skip: true,
                value,
                error,
            });
        }
        if let Some(value) = self.apply_interrupt(&mut active, run_id, session_id)? {
            middleware_call.call = active.clone();
            return Ok(PreparedTool {
                middleware_call,
                active,
                tool: None,
                skip: true,
                value,
                error: None,
            });
        }
        middleware_call.call = active.clone();
        if active.name != original_name || active.arguments != original_arguments {
            self.authorize(&Action {
                kind: "tool.invoke".to_string(),
                session_id: session_id.to_string(),
                tool_name: Some(active.name.clone()),
                arguments: Some(active.arguments.clone()),
            })?;
        }
        let tools = self.options.tools.as_ref().ok_or_else(|| {
            PraxoError::tool_not_found(format!("tool {} is not registered", active.name))
        })?;
        let tool = tools.get(&active.name)?;
        let mut data = Map::new();
        data.insert("name".to_string(), Value::String(active.name.clone()));
        data.insert("arguments".to_string(), Value::Object(active.arguments.clone()));
        self.emit("tool.call", session_id, run_id, Some(data))?;
        Ok(PreparedTool {
            middleware_call,
            active,
            tool: Some(tool),
            skip: false,
            value: Value::Null,
            error: None,
        })
    }

    fn apply_interrupt(
        &self,
        call: &mut ToolCall,
        run_id: &str,
        session_id: &str,
    ) -> Result<Option<Value>> {
        if !self.options.interrupt_on.iter().any(|name| name == &call.name) {
            return Ok(None);
        }
        if self.options.on_interrupt_decision.is_none() && self.options.on_interrupt.is_none()
        {
            return Err(PraxoError::interrupt_unhandled());
        }
        let mut data = Map::new();
        data.insert("name".to_string(), Value::String(call.name.clone()));
        data.insert("arguments".to_string(), Value::Object(call.arguments.clone()));
        self.emit("tool.interrupt", session_id, run_id, Some(data))?;
        let interrupt = Interrupt {
            run_id: run_id.to_string(),
            session_id: session_id.to_string(),
            call: call.clone(),
        };
        if let Some(handler) = &self.options.on_interrupt_decision {
            let decision = handler(&interrupt)?;
            match decision.action {
                InterruptAction::Approve => Ok(None),
                InterruptAction::Edit => {
                    let arguments = decision.arguments.ok_or_else(|| {
                        PraxoError::interrupt_decision_invalid(
                            "agent: edit requires arguments",
                        )
                    })?;
                    call.arguments = arguments;
                    Ok(None)
                }
                InterruptAction::Reject => Err(PraxoError::approval_denied(format!(
                    "agent: tool call denied by approval: {}: {}",
                    call.name, decision.reason
                ))),
                InterruptAction::Respond => Ok(Some(Value::String(decision.response))),
            }
        } else {
            let approval = self
                .options
                .on_interrupt
                .as_ref()
                .expect("approval handler checked");
            if !approval(&interrupt)? {
                return Err(PraxoError::approval_denied(format!(
                    "agent: tool call denied by approval: {}",
                    call.name
                )));
            }
            Ok(None)
        }
    }

    fn execute_prepared(&self, prepared: &PreparedTool) -> ToolResult {
        if let Err(error) = self.throw_if_cancelled() {
            return ToolResult {
                value: Value::Null,
                error: Some(error),
            };
        }
        if prepared.skip {
            return ToolResult {
                value: prepared.value.clone(),
                error: prepared.error.clone(),
            };
        }
        let tool = prepared.tool.as_ref().expect("prepared tool");
        match tool.invoke(&prepared.active.arguments) {
            Ok(value) => ToolResult { value, error: None },
            Err(error) => ToolResult {
                value: Value::Null,
                error: Some(error),
            },
        }
    }

    fn finish_tool(&self, prepared: &PreparedTool, mut result: ToolResult) -> Result<Message> {
        self.after_tool(&prepared.middleware_call, &mut result)?;
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
                let reference =
                    offloader.offload(&prepared.active.name, &prepared.active.id, raw)?;
                if reference.is_empty() {
                    return Err(PraxoError::new(
                        "AGENT_OFFLOAD",
                        "agent: offloader returned an empty placeholder",
                    ));
                }
                content = reference;
            }
        }
        Ok(Message::tool(content, prepared.active.id.clone()))
    }

    fn before_run(
        &self,
        run_id: &str,
        prompt: &str,
        entered: &mut Vec<usize>,
    ) -> Result<()> {
        let state = RunState {
            run_id: run_id.to_string(),
            prompt: prompt.to_string(),
        };
        for (index, middleware) in self.middleware.iter().enumerate() {
            entered.push(index);
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

    fn after_run_entered(
        &self,
        entered: &[usize],
        mut result: Option<&mut RunResult>,
        error: Option<&PraxoError>,
    ) -> Option<PraxoError> {
        let mut first_error = None;
        for index in entered {
            let Some(middleware) = self.middleware.get(*index) else {
                continue;
            };
            if let Err(caught) =
                middleware.after_run(result.as_deref_mut(), error)
            {
                if first_error.is_none() {
                    first_error = Some(caught);
                }
            }
        }
        first_error
    }

    fn throw_if_cancelled(&self) -> Result<()> {
        if self
            .options
            .cancellation
            .as_ref()
            .is_some_and(CancellationToken::is_cancelled)
        {
            return Err(PraxoError::new("AGENT_CANCELLED", "agent: cancelled"));
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



struct PreparedTool {
    middleware_call: MiddlewareToolCall,
    active: ToolCall,
    tool: Option<Arc<dyn Tool>>,
    skip: bool,
    value: Value,
    error: Option<PraxoError>,
}
