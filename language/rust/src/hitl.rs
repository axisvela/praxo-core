use std::sync::Arc;

use serde_json::{Map, Value};

use crate::errors::Result;
use crate::model::ToolCall;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InterruptAction {
    Approve,
    Edit,
    Reject,
    Respond,
}

#[derive(Debug, Clone)]
pub struct Interrupt {
    pub run_id: String,
    pub session_id: String,
    pub call: ToolCall,
}

#[derive(Debug, Clone)]
pub struct InterruptDecision {
    pub action: InterruptAction,
    pub arguments: Option<Map<String, Value>>,
    pub response: String,
    pub reason: String,
}

impl InterruptDecision {
    pub fn approve() -> Self {
        Self {
            action: InterruptAction::Approve,
            arguments: None,
            response: String::new(),
            reason: String::new(),
        }
    }
}

pub type InterruptHandler =
    Arc<dyn Fn(&Interrupt) -> Result<InterruptDecision> + Send + Sync>;
pub type InterruptApproval = Arc<dyn Fn(&Interrupt) -> Result<bool> + Send + Sync>;
