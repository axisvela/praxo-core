use std::collections::HashMap;
use std::sync::Mutex;
use std::thread::{current, ThreadId};

pub(crate) struct RunScopes {
    inner: Mutex<HashMap<ThreadId, Vec<String>>>,
}

impl RunScopes {
    pub(crate) fn new() -> Self {
        Self {
            inner: Mutex::new(HashMap::new()),
        }
    }

    pub(crate) fn push(&self, run_id: &str) {
        let mut scopes = self.inner.lock().expect("run scope poisoned");
        let stack = scopes.entry(current().id()).or_default();
        if stack.last().map(String::as_str) != Some(run_id) {
            stack.push(run_id.to_string());
        }
    }

    pub(crate) fn pop(&self) -> Option<String> {
        let thread = current().id();
        let mut scopes = self.inner.lock().expect("run scope poisoned");
        let stack = scopes.get_mut(&thread)?;
        let run_id = stack.pop();
        if stack.is_empty() {
            scopes.remove(&thread);
        }
        run_id
    }
}
