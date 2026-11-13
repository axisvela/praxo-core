use std::sync::{Arc, Barrier, Mutex};
use std::time::Duration;

use praxo_core::delegation::{
    SubagentManager, SubagentMode, SubagentRequest, SubagentResult, SubagentRunner,
    SubagentStatus,
};
use praxo_core::errors::Result;

struct Immediate;

impl SubagentRunner for Immediate {
    fn run(&self, _request: &SubagentRequest) -> Result<SubagentResult> {
        Ok(SubagentResult::output("done"))
    }
}

struct Failing;

impl SubagentRunner for Failing {
    fn run(&self, _request: &SubagentRequest) -> Result<SubagentResult> {
        Err(praxo_core::errors::PraxoError::new(
            "TEST_FAILURE",
            "boom",
        ))
    }
}

struct Blocking {
    started: Arc<Barrier>,
    release: Arc<Barrier>,
}

impl SubagentRunner for Blocking {
    fn run(&self, _request: &SubagentRequest) -> Result<SubagentResult> {
        self.started.wait();
        self.release.wait();
        Ok(SubagentResult::output("released"))
    }
}

struct Controllable {
    started: Arc<Barrier>,
    release: Arc<Barrier>,
    updates: Mutex<Vec<String>>,
}

impl SubagentRunner for Controllable {
    fn run(&self, _request: &SubagentRequest) -> Result<SubagentResult> {
        self.started.wait();
        self.release.wait();
        Ok(SubagentResult::output("released"))
    }

    fn update(&self, task_id: &str, prompt: &str) -> Result<()> {
        self.updates
            .lock()
            .expect("updates")
            .push(format!("{task_id}:{prompt}"));
        Ok(())
    }
}

fn request() -> SubagentRequest {
    SubagentRequest::new("parent", "child", "do work").mode(SubagentMode::Fork)
}

#[test]
fn launch_and_wait_complete() {
    let manager = SubagentManager::new(Arc::new(Immediate));
    let task = manager.launch(request()).expect("launch");
    assert_eq!(task.parent_session_id, "parent");
    assert_eq!(task.agent_id, "child");
    assert_eq!(task.mode, SubagentMode::Fork);
    let final_task = manager
        .wait(&task.id, Some(Duration::from_secs(2)))
        .expect("wait");
    assert_eq!(final_task.status, SubagentStatus::Completed);
    assert_eq!(final_task.output, "done");
}

#[test]
fn failure_is_reported() {
    let manager = SubagentManager::new(Arc::new(Failing));
    let task = manager.launch(request()).expect("launch");
    let final_task = manager
        .wait(&task.id, Some(Duration::from_secs(2)))
        .expect("wait");
    assert_eq!(final_task.status, SubagentStatus::Failed);
    assert!(final_task.error.contains("boom"));
}

#[test]
fn cancel_marks_running_task() {
    let started = Arc::new(Barrier::new(2));
    let release = Arc::new(Barrier::new(2));
    let manager = SubagentManager::new(Arc::new(Blocking {
        started: Arc::clone(&started),
        release: Arc::clone(&release),
    }));
    let task = manager.launch(request()).expect("launch");
    started.wait();
    assert_eq!(manager.check(&task.id).unwrap().status, SubagentStatus::Running);
    manager.cancel(&task.id).expect("cancel");
    let final_task = manager
        .wait(&task.id, Some(Duration::from_secs(2)))
        .expect("wait");
    assert_eq!(final_task.status, SubagentStatus::Canceled);
    release.wait();
}

#[test]
fn update_forwards_to_controllable_runner() {
    let started = Arc::new(Barrier::new(2));
    let release = Arc::new(Barrier::new(2));
    let runner = Arc::new(Controllable {
        started: Arc::clone(&started),
        release: Arc::clone(&release),
        updates: Mutex::new(Vec::new()),
    });
    let manager = SubagentManager::new(runner.clone());
    let task = manager.launch(request()).expect("launch");
    started.wait();
    manager.update(&task.id, "steer").expect("update");
    assert_eq!(
        runner.updates.lock().expect("updates").as_slice(),
        [format!("{}:steer", task.id)]
    );
    release.wait();
    let final_task = manager
        .wait(&task.id, Some(Duration::from_secs(2)))
        .expect("wait");
    assert_eq!(final_task.status, SubagentStatus::Completed);
}

#[test]
fn unknown_task_is_rejected() {
    let manager = SubagentManager::new(Arc::new(Immediate));
    assert!(manager.check("missing").is_none());
    assert!(manager.wait("missing", Some(Duration::from_millis(10))).is_err());
}
