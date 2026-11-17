use std::collections::HashSet;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use serde_json::{json, Map, Value};

use praxo_core::agent::{Agent, AgentOptions, CancellationToken, Session};
use praxo_core::errors::{PraxoError, Result};
use praxo_core::middleware::{Middleware, MiddlewareToolCall};
use praxo_core::model::{Message, Model, Request, Response, ToolCall};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

#[derive(Clone)]
pub struct SharedBudget {
    remaining: Arc<AtomicUsize>,
}

impl SharedBudget {
    fn new(remaining: usize) -> Self {
        Self {
            remaining: Arc::new(AtomicUsize::new(remaining)),
        }
    }

    fn available(&self) -> bool {
        self.remaining.load(Ordering::SeqCst) > 0
    }

    fn take(&self) -> bool {
        let mut current = self.remaining.load(Ordering::SeqCst);
        while current > 0 {
            match self.remaining.compare_exchange(
                current,
                current - 1,
                Ordering::SeqCst,
                Ordering::SeqCst,
            ) {
                Ok(_) => return true,
                Err(next) => current = next,
            }
        }
        false
    }
}

#[derive(Clone)]
pub struct Authority {
    allowed: HashSet<String>,
    pub delegable: HashSet<String>,
    max_depth: usize,
    max_children: usize,
    depth: usize,
    budget: SharedBudget,
    policy: Option<Arc<dyn Hook>>,
}

pub struct ChildScope {
    pub authority: Authority,
    release: Box<dyn Fn() + Send + Sync>,
}

impl ChildScope {
    pub fn release(&self) {
        (self.release)();
    }

    pub fn run(
        &self,
        model: Arc<dyn Model>,
        tools: &Registry,
        prompt: &str,
        token: Option<CancellationToken>,
        middleware: Vec<Box<dyn Middleware>>,
    ) -> Result<()> {
        let mut names: Vec<String> = self.authority.allowed.iter().cloned().collect();
        names.sort();
        let mut scoped = Registry::new();
        for name in &names {
            scoped.register(Arc::new(BudgetedTool {
                inner: tools.get(name)?,
                budget: self.authority.budget.clone(),
            }));
        }
        let mut options = AgentOptions::new(model);
        options.tools = Some(Arc::new(scoped));
        options.max_steps = 3;
        options.allowed_tools = names;
        options.policy = self.authority.policy.clone();
        options.cancellation = token;
        options.middleware = middleware;
        options.require_policy = true;
        options.require_tool_scope = true;
        Agent::new(options)?.run(&Session::new("governed-delegation-child"), prompt)?;
        Ok(())
    }
}

pub struct Governor {
    pub authority: Authority,
    active: Arc<AtomicUsize>,
}

impl Governor {
    pub fn new(authority: Authority) -> Self {
        Self {
            authority,
            active: Arc::new(AtomicUsize::new(0)),
        }
    }

    pub fn delegate(
        &self,
        allowed: Vec<String>,
        delegable: Vec<String>,
        policy: Option<Arc<dyn Hook>>,
    ) -> std::result::Result<ChildScope, String> {
        let allowed: HashSet<String> = allowed.into_iter().collect();
        let delegable: HashSet<String> = delegable.into_iter().collect();
        let depth = self.authority.depth + 1;
        if depth > self.authority.max_depth {
            return Err("delegation depth exceeded".to_string());
        }
        if allowed.is_empty() {
            return Err("delegation tool scope is empty".to_string());
        }
        if !allowed.is_subset(&self.authority.delegable) {
            return Err("delegation scope exceeds parent".to_string());
        }
        if !allowed.is_subset(&self.authority.allowed) {
            return Err("delegation scope is not allowed".to_string());
        }
        if !delegable.is_subset(&self.authority.delegable) {
            return Err("child delegable scope exceeds parent".to_string());
        }
        if !self.authority.budget.available() {
            return Err("delegation budget exhausted".to_string());
        }
        let previous = self.active.fetch_add(1, Ordering::SeqCst);
        if previous >= self.authority.max_children {
            self.active.fetch_sub(1, Ordering::SeqCst);
            return Err("delegation child limit exceeded".to_string());
        }
        let active = self.active.clone();
        let released = Arc::new(AtomicUsize::new(0));
        let release = Box::new(move || {
            if released.fetch_add(1, Ordering::SeqCst) == 0 {
                active.fetch_sub(1, Ordering::SeqCst);
            }
        });
        Ok(ChildScope {
            authority: Authority {
                allowed,
                delegable,
                max_depth: self.authority.max_depth,
                max_children: self.authority.max_children,
                depth,
                budget: self.authority.budget.clone(),
                policy: Some(Arc::new(PolicyChain::new(vec![
                    self.authority.policy.clone(),
                    policy,
                ]))),
            },
            release,
        })
    }
}

pub struct PolicyChain {
    hooks: Vec<Arc<dyn Hook>>,
}

impl PolicyChain {
    fn new(hooks: Vec<Option<Arc<dyn Hook>>>) -> Self {
        Self {
            hooks: hooks.into_iter().flatten().collect(),
        }
    }
}

impl Hook for PolicyChain {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        for hook in &self.hooks {
            let decision = hook.authorize(action)?;
            if !decision.allowed {
                return Ok(decision);
            }
        }
        Ok(Decision::allow("delegation policy chain allowed"))
    }
}

pub struct BudgetedTool {
    inner: Arc<dyn Tool>,
    budget: SharedBudget,
}

impl Tool for BudgetedTool {
    fn name(&self) -> &str {
        self.inner.name()
    }

    fn description(&self) -> &str {
        self.inner.description()
    }

    fn invoke(&self, args: &Map<String, Value>) -> Result<Value> {
        if !self.budget.take() {
            return Err(PraxoError::new(
                "DELEGATION_BUDGET",
                "delegation budget exhausted",
            ));
        }
        self.inner.invoke(args)
    }
}

pub struct FixtureModel {
    pub tool_name: String,
    pub arguments: Map<String, Value>,
    pub completion: String,
}

impl Model for FixtureModel {
    fn generate(&self, request: &Request) -> Result<Response> {
        let last_is_tool = request
            .messages
            .last()
            .map(|message| message.role == "tool")
            .unwrap_or(false);
        if last_is_tool {
            return Ok(Response {
                message: Message::assistant(&self.completion, Vec::new()),
                ..Response::default()
            });
        }
        Ok(Response {
            message: Message {
                role: "assistant".to_string(),
                content: Some(String::new()),
                content_blocks: Vec::new(),
                tool_calls: vec![ToolCall {
                    id: "call-1".to_string(),
                    name: self.tool_name.clone(),
                    arguments: self.arguments.clone(),
                }],
                tool_id: None,
            },
            ..Response::default()
        })
    }
}

pub struct RecordTool {
    pub calls: Arc<AtomicUsize>,
}

impl Tool for RecordTool {
    fn name(&self) -> &str {
        "record"
    }

    fn description(&self) -> &str {
        "Record a child result in an in-memory counter."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(json!("recorded"))
    }
}

pub struct ParentOnlyTool {
    pub calls: Arc<AtomicUsize>,
}

impl Tool for ParentOnlyTool {
    fn name(&self) -> &str {
        "parent_only"
    }

    fn description(&self) -> &str {
        "A tool that must remain outside the child scope."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(json!("parent-effect"))
    }
}

pub struct AllowAll;

impl Hook for AllowAll {
    fn authorize(&self, _action: &Action) -> Result<Decision> {
        Ok(Decision::allow("root"))
    }
}

pub struct RecordPolicy;

impl Hook for RecordPolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        if action.kind != "tool.invoke" {
            return Ok(Decision::allow("non-tool action"));
        }
        if action.tool_name.as_deref() != Some("record") {
            return Ok(Decision::deny("child may only record"));
        }
        if action
            .arguments
            .as_ref()
            .and_then(|arguments| arguments.get("target"))
            .and_then(Value::as_str)
            == Some("blocked")
        {
            return Ok(Decision::deny("blocked target"));
        }
        Ok(Decision::allow("record allowed"))
    }
}

pub struct EditMiddleware;

impl Middleware for EditMiddleware {
    fn before_tool(&self, call: &mut MiddlewareToolCall) -> Result<()> {
        call.call
            .arguments
            .insert("target".to_string(), json!("blocked"));
        Ok(())
    }
}

pub fn root_authority(
    allowed: &[&str],
    delegable: &[&str],
    max_depth: usize,
    max_children: usize,
    budget: usize,
) -> Authority {
    Authority {
        allowed: allowed.iter().map(|item| item.to_string()).collect(),
        delegable: delegable.iter().map(|item| item.to_string()).collect(),
        max_depth,
        max_children,
        depth: 0,
        budget: SharedBudget::new(budget),
        policy: Some(Arc::new(AllowAll)),
    }
}

pub fn args(target: &str) -> Map<String, Value> {
    let mut arguments = Map::new();
    arguments.insert("target".to_string(), json!(target));
    arguments
}
