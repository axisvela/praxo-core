use std::collections::HashMap;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex, Weak};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use serde_json::{json, Map, Value};

use crate::errors::{PraxoError, Result};

use super::McpServerConfig;

const CLOSE_POLL: Duration = Duration::from_millis(50);
const CLOSE_POLLS: usize = 100;

pub(crate) struct Inner {
    child: Mutex<Child>,
    stdin: Mutex<Option<BufWriter<ChildStdin>>>,
    pending: Mutex<HashMap<u64, Sender<Result<Map<String, Value>>>>>,
    next_id: AtomicU64,
    closed: AtomicBool,
    reader: Mutex<Option<JoinHandle<()>>>,
    timeout: Duration,
    protocol_version: Mutex<String>,
    server_info: Mutex<Map<String, Value>>,
    server_capabilities: Mutex<Map<String, Value>>,
}

impl Inner {
    pub(crate) fn spawn(config: McpServerConfig, timeout: Duration) -> Result<Arc<Self>> {
        if config.command.is_empty() {
            return Err(PraxoError::mcp_transport("mcp: command is required"));
        }
        let mut command = Command::new(&config.command);
        command
            .args(&config.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());
        if let Some(cwd) = &config.cwd {
            command.current_dir(cwd);
        }
        for (key, value) in &config.env {
            command.env(key, value);
        }
        let mut child = command.spawn().map_err(|error| {
            PraxoError::mcp_transport(format!("mcp: failed to start server: {error}"))
        })?;
        let stdin = match child.stdin.take() {
            Some(stdin) => stdin,
            None => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(PraxoError::mcp_transport(
                    "mcp: failed to open server stdin",
                ));
            }
        };
        let stdout = match child.stdout.take() {
            Some(stdout) => stdout,
            None => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(PraxoError::mcp_transport(
                    "mcp: failed to open server stdout",
                ));
            }
        };
        let inner = Self {
            child: Mutex::new(child),
            stdin: Mutex::new(Some(BufWriter::new(stdin))),
            pending: Mutex::new(HashMap::new()),
            next_id: AtomicU64::new(1),
            closed: AtomicBool::new(false),
            reader: Mutex::new(None),
            timeout,
            protocol_version: Mutex::new(String::new()),
            server_info: Mutex::new(Map::new()),
            server_capabilities: Mutex::new(Map::new()),
        };
        let inner = Arc::new(inner);
        let weak = Arc::downgrade(&inner);
        let handle = thread::spawn(move || reader_loop(weak, BufReader::new(stdout)));
        *inner.reader.lock().expect("mcp reader") = Some(handle);
        Ok(inner)
    }

    pub(crate) fn protocol_version(&self) -> String {
        self.protocol_version.lock().expect("mcp protocol").clone()
    }

    pub(crate) fn set_protocol_version(&self, value: String) {
        *self.protocol_version.lock().expect("mcp protocol") = value;
    }

    pub(crate) fn server_info(&self) -> Map<String, Value> {
        self.server_info.lock().expect("mcp server info").clone()
    }

    pub(crate) fn set_server_info(&self, value: Map<String, Value>) {
        *self.server_info.lock().expect("mcp server info") = value;
    }

    pub(crate) fn server_capabilities(&self) -> Map<String, Value> {
        self.server_capabilities
            .lock()
            .expect("mcp capabilities")
            .clone()
    }

    pub(crate) fn set_server_capabilities(&self, value: Map<String, Value>) {
        *self.server_capabilities.lock().expect("mcp capabilities") = value;
    }

    pub(crate) fn pid(&self) -> Option<u32> {
        Some(self.child.lock().expect("mcp child").id())
    }

    pub(crate) fn is_running(&self) -> bool {
        match self.child.lock().expect("mcp child").try_wait() {
            Ok(Some(_)) => false,
            Ok(None) => true,
            Err(_) => false,
        }
    }

    pub(crate) fn request(
        &self,
        method: &str,
        params: Option<Value>,
        timeout: Option<Duration>,
    ) -> Result<Map<String, Value>> {
        if self.closed.load(Ordering::SeqCst) {
            return Err(PraxoError::mcp_closed("mcp: client is closed"));
        }
        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let (sender, receiver) = mpsc::channel();
        self.pending.lock().expect("mcp pending").insert(id, sender);
        let message = request_message(id, method, params);
        if let Err(error) = self.send(&message) {
            self.pending.lock().expect("mcp pending").remove(&id);
            return Err(error);
        }
        let effective = timeout.unwrap_or(self.timeout);
        match receiver.recv_timeout(effective) {
            Ok(Ok(response)) => {
                if let Some(error) = response.get("error") {
                    return Err(rpc_error(method, error));
                }
                match response.get("result") {
                    None | Some(Value::Null) => Ok(Map::new()),
                    Some(Value::Object(result)) => Ok(result.clone()),
                    Some(_) => Err(PraxoError::mcp_protocol(format!(
                        "mcp: {method} result must be an object"
                    ))),
                }
            }
            Ok(Err(error)) => Err(error),
            Err(RecvTimeoutError::Timeout) => {
                self.pending.lock().expect("mcp pending").remove(&id);
                self.cancel(id, "timeout");
                Err(PraxoError::mcp_timeout(format!(
                    "mcp: {method} timed out after {}ms",
                    effective.as_millis()
                )))
            }
            Err(RecvTimeoutError::Disconnected) => {
                self.pending.lock().expect("mcp pending").remove(&id);
                Err(PraxoError::mcp_closed("mcp: connection closed"))
            }
        }
    }

    pub(crate) fn call_tool(
        &self,
        name: &str,
        arguments: Map<String, Value>,
        timeout: Option<Duration>,
    ) -> Result<Value> {
        if name.is_empty() {
            return Err(PraxoError::mcp_protocol("mcp: tool name is required"));
        }
        let params = json!({"name": name, "arguments": Value::Object(arguments)});
        let result = self.request("tools/call", Some(params), timeout)?;
        if result
            .get("isError")
            .and_then(Value::as_bool)
            .unwrap_or(false)
        {
            return Err(PraxoError::mcp_tool_error(format!(
                "mcp: tool {} failed: {}",
                name,
                text_content(&result)
            )));
        }
        if let Some(structured) = result.get("structuredContent") {
            if !structured.is_null() {
                return Ok(structured.clone());
            }
        }
        let texts = text_contents(&result);
        match texts.len() {
            0 => Ok(Value::Null),
            1 => Ok(Value::String(texts[0].clone())),
            _ => Ok(Value::Array(texts.into_iter().map(Value::String).collect())),
        }
    }

    pub(crate) fn notify(&self, method: &str, params: Option<Value>) -> Result<()> {
        let mut message = Map::new();
        message.insert("jsonrpc".to_string(), json!("2.0"));
        message.insert("method".to_string(), json!(method));
        if let Some(params) = params {
            message.insert("params".to_string(), params);
        }
        self.send(&Value::Object(message))
    }

    fn cancel(&self, id: u64, reason: &str) {
        let _ = self.notify(
            "notifications/cancelled",
            Some(json!({"requestId": id, "reason": reason})),
        );
    }

    fn send(&self, message: &Value) -> Result<()> {
        let line = serde_json::to_string(message)
            .map_err(|error| PraxoError::mcp_protocol(format!("mcp: {error}")))?;
        let mut guard = self.stdin.lock().expect("mcp stdin");
        let writer = guard
            .as_mut()
            .ok_or_else(|| PraxoError::mcp_transport("mcp: transport is not started"))?;
        writer
            .write_all(line.as_bytes())
            .and_then(|_| writer.write_all(b"\n"))
            .and_then(|_| writer.flush())
            .map_err(|error| PraxoError::mcp_transport(format!("mcp: write failed: {error}")))
    }

    fn fail_all(&self, error: PraxoError) {
        let pending: Vec<Sender<Result<Map<String, Value>>>> = {
            let mut guard = self.pending.lock().expect("mcp pending");
            guard.drain().map(|(_, sender)| sender).collect()
        };
        for sender in pending {
            let _ = sender.send(Err(error.clone()));
        }
    }

    pub(crate) fn close(&self) {
        if self.closed.swap(true, Ordering::SeqCst) {
            return;
        }
        let ids: Vec<u64> = self
            .pending
            .lock()
            .expect("mcp pending")
            .keys()
            .copied()
            .collect();
        for id in ids {
            self.cancel(id, "client closed");
        }
        {
            let mut guard = self.stdin.lock().expect("mcp stdin");
            if let Some(mut writer) = guard.take() {
                let _ = writer.flush();
            }
        }
        let mut exited = false;
        for _ in 0..CLOSE_POLLS {
            match self.child.lock().expect("mcp child").try_wait() {
                Ok(Some(_)) => {
                    exited = true;
                    break;
                }
                Ok(None) => thread::sleep(CLOSE_POLL),
                Err(_) => break,
            }
        }
        if !exited {
            let mut child = self.child.lock().expect("mcp child");
            let _ = child.kill();
            let _ = child.wait();
        }
        if let Some(handle) = self.reader.lock().expect("mcp reader").take() {
            if handle.thread().id() != thread::current().id() {
                let _ = handle.join();
            }
        }
        self.fail_all(PraxoError::mcp_closed("mcp: client closed"));
    }
}

impl Drop for Inner {
    fn drop(&mut self) {
        self.close();
    }
}

fn reader_loop(inner: Weak<Inner>, reader: BufReader<ChildStdout>) {
    for line in reader.lines() {
        let Some(inner) = inner.upgrade() else {
            return;
        };
        let line = match line {
            Ok(line) => line,
            Err(error) => {
                inner.fail_all(PraxoError::mcp_transport(format!(
                    "mcp: read failed: {error}"
                )));
                return;
            }
        };
        if line.trim().is_empty() {
            continue;
        }
        let message: Value = match serde_json::from_str(&line) {
            Ok(message) => message,
            Err(_) => {
                inner.fail_all(PraxoError::mcp_protocol("mcp: server sent invalid JSON"));
                return;
            }
        };
        if message.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
            inner.fail_all(PraxoError::mcp_protocol("mcp: invalid JSON-RPC version"));
            return;
        }
        let Some(id) = message.get("id").and_then(Value::as_u64) else {
            continue;
        };
        let sender = inner.pending.lock().expect("mcp pending").remove(&id);
        if let Some(sender) = sender {
            let _ = sender.send(Ok(message.as_object().cloned().unwrap_or_default()));
        }
    }
    if let Some(inner) = inner.upgrade() {
        inner.fail_all(PraxoError::mcp_closed("mcp: connection closed"));
    }
}

fn request_message(id: u64, method: &str, params: Option<Value>) -> Value {
    let mut message = Map::new();
    message.insert("jsonrpc".to_string(), json!("2.0"));
    message.insert("id".to_string(), json!(id));
    message.insert("method".to_string(), json!(method));
    if let Some(params) = params {
        message.insert("params".to_string(), params);
    }
    Value::Object(message)
}

fn rpc_error(method: &str, error: &Value) -> PraxoError {
    let Some(object) = error.as_object() else {
        return PraxoError::mcp_protocol(format!("mcp: {method} returned an invalid error object"));
    };
    let code = object.get("code").map(Value::to_string).unwrap_or_default();
    let message = object
        .get("message")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or("JSON-RPC error");
    PraxoError::mcp_rpc(format!("mcp: {method} failed: {message} ({code})"))
}

fn text_contents(result: &Map<String, Value>) -> Vec<String> {
    let Some(content) = result.get("content").and_then(Value::as_array) else {
        return Vec::new();
    };
    content
        .iter()
        .filter_map(|item| {
            let block = item.as_object()?;
            if block.get("type").and_then(Value::as_str) != Some("text") {
                return None;
            }
            block
                .get("text")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .collect()
}

fn text_content(result: &Map<String, Value>) -> String {
    text_contents(result).join("\n")
}
