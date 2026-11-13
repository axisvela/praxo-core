use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant, SystemTime};

use serde_json::Value;

use crate::errors::{PraxoError, Result};
use crate::model::{Message, Usage};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubagentMode {
    Isolated,
    Fork,
}

impl SubagentMode {
    pub fn wire(&self) -> &'static str {
        match self {
            SubagentMode::Isolated => "isolated",
            SubagentMode::Fork => "fork",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubagentStatus {
    Queued,
    Running,
    Completed,
    Failed,
    Canceled,
}

impl SubagentStatus {
    pub fn wire(&self) -> &'static str {
        match self {
            SubagentStatus::Queued => "queued",
            SubagentStatus::Running => "running",
            SubagentStatus::Completed => "completed",
            SubagentStatus::Failed => "failed",
            SubagentStatus::Canceled => "canceled",
        }
    }

    pub fn terminal(&self) -> bool {
        matches!(
            self,
            SubagentStatus::Completed | SubagentStatus::Failed | SubagentStatus::Canceled
        )
    }
}

#[derive(Debug, Clone)]
pub struct SubagentRequest {
    pub parent_session_id: String,
    pub agent_id: String,
    pub prompt: String,
    pub context: HashMap<String, Value>,
    pub mode: SubagentMode,
    pub history: Vec<Message>,
}

impl SubagentRequest {
    pub fn new(
        parent_session_id: impl Into<String>,
        agent_id: impl Into<String>,
        prompt: impl Into<String>,
    ) -> Self {
        Self {
            parent_session_id: parent_session_id.into(),
            agent_id: agent_id.into(),
            prompt: prompt.into(),
            context: HashMap::new(),
            mode: SubagentMode::Isolated,
            history: Vec::new(),
        }
    }

    pub fn mode(mut self, mode: SubagentMode) -> Self {
        self.mode = mode;
        self
    }

    pub fn history(mut self, history: Vec<Message>) -> Self {
        self.history = history;
        self
    }
}

#[derive(Debug, Clone)]
pub struct SubagentResult {
    pub task_id: String,
    pub agent_id: String,
    pub output: String,
    pub usage: Option<Usage>,
}

impl SubagentResult {
    pub fn output(output: impl Into<String>) -> Self {
        Self {
            task_id: String::new(),
            agent_id: String::new(),
            output: output.into(),
            usage: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct SubagentTask {
    pub id: String,
    pub parent_session_id: String,
    pub agent_id: String,
    pub mode: SubagentMode,
    pub status: SubagentStatus,
    pub output: String,
    pub error: String,
    pub created_at: SystemTime,
    pub updated_at: SystemTime,
}

pub trait SubagentRunner: Send + Sync {
    fn run(&self, request: &SubagentRequest) -> Result<SubagentResult>;

    fn update(&self, _task_id: &str, _prompt: &str) -> Result<()> {
        Err(PraxoError::new(
            "AGENT_SUBAGENT_UPDATE_UNSUPPORTED",
            "agent: subagent update unsupported",
        ))
    }
}

struct Slot {
    task: Mutex<SubagentTask>,
    ready: Condvar,
}

impl Slot {
    fn set(&self, status: SubagentStatus, output: &str, error: &str) {
        let mut task = self.task.lock().expect("task");
        if task.status.terminal() {
            return;
        }
        task.status = status;
        task.output = output.to_string();
        task.error = error.to_string();
        task.updated_at = SystemTime::now();
        self.ready.notify_all();
    }
}

pub struct SubagentManager {
    runner: Arc<dyn SubagentRunner>,
    tasks: Mutex<HashMap<String, Arc<Slot>>>,
    sequence: AtomicU64,
}

impl SubagentManager {
    pub fn new(runner: Arc<dyn SubagentRunner>) -> Self {
        Self {
            runner,
            tasks: Mutex::new(HashMap::new()),
            sequence: AtomicU64::new(0),
        }
    }

    pub fn launch(&self, request: SubagentRequest) -> Result<SubagentTask> {
        if request.parent_session_id.is_empty() || request.agent_id.is_empty() {
            return Err(PraxoError::new(
                "AGENT_SUBAGENT_INVALID",
                "agent: subagent parent session and agent id are required",
            ));
        }
        let id = format!(
            "subagent-{}",
            self.sequence.fetch_add(1, Ordering::SeqCst) + 1
        );
        let now = SystemTime::now();
        let task = SubagentTask {
            id: id.clone(),
            parent_session_id: request.parent_session_id.clone(),
            agent_id: request.agent_id.clone(),
            mode: request.mode,
            status: SubagentStatus::Queued,
            output: String::new(),
            error: String::new(),
            created_at: now,
            updated_at: now,
        };
        let slot = Arc::new(Slot {
            task: Mutex::new(task.clone()),
            ready: Condvar::new(),
        });
        self.tasks
            .lock()
            .expect("tasks")
            .insert(id.clone(), slot.clone());
        let runner = Arc::clone(&self.runner);
        std::thread::spawn(move || {
            slot.set(SubagentStatus::Running, "", "");
            match runner.run(&request) {
                Ok(result) => slot.set(SubagentStatus::Completed, &result.output, ""),
                Err(error) => slot.set(SubagentStatus::Failed, "", &error.to_string()),
            }
        });
        Ok(task)
    }

    pub fn check(&self, task_id: &str) -> Option<SubagentTask> {
        self.tasks
            .lock()
            .expect("tasks")
            .get(task_id)
            .map(|slot| slot.task.lock().expect("task").clone())
    }

    pub fn wait(
        &self,
        task_id: &str,
        timeout: Option<Duration>,
    ) -> Result<SubagentTask> {
        let slot = self.slot(task_id)?;
        let deadline = timeout.map(|value| Instant::now() + value);
        let mut task = slot.task.lock().expect("task");
        loop {
            if task.status.terminal() {
                return Ok(task.clone());
            }
            task = match deadline {
                None => slot.ready.wait(task).expect("task"),
                Some(deadline) => {
                    let now = Instant::now();
                    if now >= deadline {
                        return Err(PraxoError::new(
                            "AGENT_SUBAGENT_TIMEOUT",
                            "agent: subagent wait timed out",
                        ));
                    }
                    slot.ready
                        .wait_timeout(task, deadline - now)
                        .expect("task")
                        .0
                }
            };
        }
    }

    pub fn update(&self, task_id: &str, prompt: &str) -> Result<()> {
        let slot = self.slot(task_id)?;
        {
            let task = slot.task.lock().expect("task");
            if task.status != SubagentStatus::Running {
                return Err(PraxoError::new(
                    "AGENT_SUBAGENT_NOT_RUNNING",
                    format!("agent: subagent task \"{task_id}\" is not running"),
                ));
            }
        }
        self.runner.update(task_id, prompt)
    }

    pub fn cancel(&self, task_id: &str) -> Result<()> {
        let slot = self.slot(task_id)?;
        let mut task = slot.task.lock().expect("task");
        if !task.status.terminal() {
            task.status = SubagentStatus::Canceled;
            task.updated_at = SystemTime::now();
            slot.ready.notify_all();
        }
        Ok(())
    }

    fn slot(&self, task_id: &str) -> Result<Arc<Slot>> {
        self.tasks
            .lock()
            .expect("tasks")
            .get(task_id)
            .cloned()
            .ok_or_else(|| {
                PraxoError::new(
                    "AGENT_SUBAGENT_NOT_FOUND",
                    format!("agent: unknown subagent task \"{task_id}\""),
                )
            })
    }
}
