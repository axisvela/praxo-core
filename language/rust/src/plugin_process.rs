use std::fmt;
use std::io::{BufRead, BufReader, Read, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::{json, Value};

pub const PROTOCOL_VERSION: i64 = 1;
pub const CONTROL_SERVICE: &str = "host.control";
pub const HEALTH_METHOD: &str = "health";
pub const SHUTDOWN_METHOD: &str = "shutdown";
pub const CANCEL_METHOD: &str = "cancel";
pub const DEFAULT_TOKEN_ENV: &str = "PRAXOVELA_PLUGIN_TOKEN";

#[derive(Debug, Clone)]
pub struct ProcessError {
    pub code: String,
    pub message: String,
}

impl ProcessError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }
}

impl fmt::Display for ProcessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for ProcessError {}

#[derive(Debug, Clone)]
pub struct ProcessConfig {
    pub plugin_id: String,
    pub path: String,
    pub args: Vec<String>,
    pub dir: Option<String>,
    pub env: Option<Vec<(String, String)>>,
    pub token: String,
    pub token_env_var: String,
    pub start_timeout: Duration,
    pub invoke_timeout: Duration,
    pub grace_period: Duration,
    pub max_frame: usize,
}

impl ProcessConfig {
    pub fn new(plugin_id: impl Into<String>, path: impl Into<String>) -> Self {
        Self {
            plugin_id: plugin_id.into(),
            path: path.into(),
            args: Vec::new(),
            dir: None,
            env: None,
            token: String::new(),
            token_env_var: DEFAULT_TOKEN_ENV.to_string(),
            start_timeout: Duration::from_secs(10),
            invoke_timeout: Duration::from_secs(30),
            grace_period: Duration::from_secs(5),
            max_frame: 8 << 20,
        }
    }
}

pub struct ProcessHost {
    config: ProcessConfig,
    token: String,
    child: Option<Child>,
    stdin: Option<ChildStdin>,
    responses: Option<Receiver<Option<String>>>,
    stderr: Arc<Mutex<String>>,
    sequence: u64,
    active: bool,
}

impl ProcessHost {
    pub fn new(config: ProcessConfig) -> Result<Self, ProcessError> {
        if config.plugin_id.is_empty() {
            return Err(ProcessError::new(
                "INVALID_REQUEST",
                "plugin: PluginID is required",
            ));
        }
        if config.path.is_empty() {
            return Err(ProcessError::new(
                "INVALID_REQUEST",
                "plugin: path is required",
            ));
        }
        let token = if config.token.is_empty() {
            random_token()
        } else {
            config.token.clone()
        };
        Ok(Self {
            config,
            token,
            child: None,
            stdin: None,
            responses: None,
            stderr: Arc::new(Mutex::new(String::new())),
            sequence: 0,
            active: false,
        })
    }

    pub fn plugin_id(&self) -> &str {
        &self.config.plugin_id
    }

    pub fn is_active(&self) -> bool {
        self.active
    }

    pub fn stderr_text(&self) -> String {
        self.stderr
            .lock()
            .map(|value| value.clone())
            .unwrap_or_default()
    }

    pub fn start(&mut self) -> Result<(), ProcessError> {
        if self.child.is_some() {
            return Err(ProcessError::new(
                "INVALID_REQUEST",
                "plugin: host already started",
            ));
        }
        let mut command = Command::new(&self.config.path);
        command
            .args(&self.config.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if let Some(dir) = &self.config.dir {
            command.current_dir(dir);
        }
        match &self.config.env {
            Some(env) => {
                command.env_clear();
                for (key, value) in env {
                    command.env(key, value);
                }
            }
            None => {}
        }
        command.env(&self.config.token_env_var, &self.token);
        let mut child = command.spawn().map_err(|error| {
            ProcessError::new("INTERNAL", format!("plugin: spawn failed: {error}"))
        })?;
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| ProcessError::new("INTERNAL", "plugin: child stdin unavailable"))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| ProcessError::new("INTERNAL", "plugin: child stdout unavailable"))?;
        let stderr = child
            .stderr
            .take()
            .ok_or_else(|| ProcessError::new("INTERNAL", "plugin: child stderr unavailable"))?;
        let (sender, receiver) = mpsc::channel();
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                match line {
                    Ok(value) => {
                        if sender.send(Some(value)).is_err() {
                            return;
                        }
                    }
                    Err(_) => break,
                }
            }
            let _ = sender.send(None);
        });
        let captured = Arc::clone(&self.stderr);
        thread::spawn(move || {
            let mut reader = BufReader::new(stderr);
            let mut buffer = [0u8; 4096];
            loop {
                match reader.read(&mut buffer) {
                    Ok(0) => break,
                    Ok(count) => {
                        if let Ok(mut text) = captured.lock() {
                            if text.len() < 16 << 10 {
                                let remaining = (16 << 10) - text.len();
                                text.push_str(&String::from_utf8_lossy(
                                    &buffer[..count.min(remaining)],
                                ));
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });
        self.child = Some(child);
        self.stdin = Some(stdin);
        self.responses = Some(receiver);
        let timeout = self.config.start_timeout;
        self.call(CONTROL_SERVICE, HEALTH_METHOD, &[], timeout)?;
        self.active = true;
        Ok(())
    }

    pub fn invoke(
        &mut self,
        service: &str,
        method: &str,
        payload: &[u8],
    ) -> Result<Vec<u8>, ProcessError> {
        self.invoke_with_timeout(service, method, payload, self.config.invoke_timeout)
    }

    pub fn invoke_with_timeout(
        &mut self,
        service: &str,
        method: &str,
        payload: &[u8],
        timeout: Duration,
    ) -> Result<Vec<u8>, ProcessError> {
        if !self.active {
            return Err(ProcessError::new(
                "NOT_ACTIVE",
                "plugin: host is not active",
            ));
        }
        self.call(service, method, payload, timeout)
    }

    pub fn stop(&mut self) {
        if self.child.is_none() {
            return;
        }
        if self.active {
            let timeout = self.config.grace_period;
            let _ = self.call(CONTROL_SERVICE, SHUTDOWN_METHOD, &[], timeout);
        }
        self.active = false;
        self.terminate_child();
    }

    fn call(
        &mut self,
        service: &str,
        method: &str,
        payload: &[u8],
        timeout: Duration,
    ) -> Result<Vec<u8>, ProcessError> {
        self.sequence += 1;
        let id = format!("req-{}", self.sequence);
        let frame = json!({
            "id": id,
            "version": PROTOCOL_VERSION,
            "plugin_id": self.config.plugin_id,
            "service": service,
            "method": method,
            "token": self.token,
            "payload": encode_base64(payload),
        });
        let encoded = serde_json::to_vec(&frame)
            .map_err(|error| ProcessError::new("INTERNAL", error.to_string()))?;
        if encoded.len() + 1 > self.config.max_frame {
            return Err(ProcessError::new(
                "INVALID_REQUEST",
                "plugin: request frame too large",
            ));
        }
        let stdin = self
            .stdin
            .as_mut()
            .ok_or_else(|| ProcessError::new("INTERNAL", "plugin: process is closed"))?;
        stdin
            .write_all(&encoded)
            .and_then(|_| stdin.write_all(b"\n"))
            .and_then(|_| stdin.flush())
            .map_err(|error| ProcessError::new("INTERNAL", error.to_string()))?;
        let receiver = self
            .responses
            .as_ref()
            .ok_or_else(|| ProcessError::new("INTERNAL", "plugin: process is closed"))?;
        let deadline = Instant::now() + timeout;
        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                self.send_cancel(&id);
                self.terminate_child();
                return Err(ProcessError::new("TIMEOUT", "plugin: invocation timed out"));
            }
            match receiver.recv_timeout(remaining) {
                Ok(Some(line)) => {
                    if let Some(result) = self.parse_response(&line, &id) {
                        return result;
                    }
                }
                Ok(None) => {
                    let detail = self.stderr_text();
                    self.terminate_child();
                    return Err(ProcessError::new(
                        "INTERNAL",
                        if detail.is_empty() {
                            "plugin: process exited".to_string()
                        } else {
                            detail.chars().take(512).collect()
                        },
                    ));
                }
                Err(RecvTimeoutError::Timeout) => {
                    self.send_cancel(&id);
                    self.terminate_child();
                    return Err(ProcessError::new("TIMEOUT", "plugin: invocation timed out"));
                }
                Err(RecvTimeoutError::Disconnected) => {
                    self.terminate_child();
                    return Err(ProcessError::new("INTERNAL", "plugin: process exited"));
                }
            }
        }
    }

    fn parse_response(&self, line: &str, id: &str) -> Option<Result<Vec<u8>, ProcessError>> {
        if line.len() > self.config.max_frame {
            return Some(Err(ProcessError::new(
                "INTERNAL",
                "plugin: response frame too large",
            )));
        }
        let value: Value = match serde_json::from_str(line) {
            Ok(value) => value,
            Err(_) => return None,
        };
        if value.get("id").and_then(Value::as_str) != Some(id) {
            return None;
        }
        if value.get("ok").and_then(Value::as_bool) != Some(true) {
            let code = value
                .get("code")
                .and_then(Value::as_str)
                .unwrap_or("INTERNAL");
            let message = value.get("message").and_then(Value::as_str).unwrap_or("");
            return Some(Err(ProcessError::new(normalize_code(code), message)));
        }
        let payload = value.get("payload").and_then(Value::as_str).unwrap_or("");
        Some(decode_base64(payload).map_err(|error| ProcessError::new("INTERNAL", error)))
    }

    fn send_cancel(&mut self, id: &str) {
        let frame = json!({
            "id": id,
            "version": PROTOCOL_VERSION,
            "plugin_id": self.config.plugin_id,
            "service": CONTROL_SERVICE,
            "method": CANCEL_METHOD,
            "token": self.token,
        });
        if let (Some(stdin), Ok(encoded)) = (self.stdin.as_mut(), serde_json::to_vec(&frame)) {
            let _ = stdin.write_all(&encoded);
            let _ = stdin.write_all(b"\n");
            let _ = stdin.flush();
        }
    }

    fn terminate_child(&mut self) {
        self.active = false;
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.stdin = None;
        self.responses = None;
    }
}

impl Drop for ProcessHost {
    fn drop(&mut self) {
        if self.child.is_some() {
            self.stop();
        }
    }
}

fn normalize_code(code: &str) -> &'static str {
    match code {
        "CAPABILITY_DENIED" => "CAPABILITY_DENIED",
        "NOT_ACTIVE" => "NOT_ACTIVE",
        "NOT_FOUND" => "NOT_FOUND",
        "INVALID_REQUEST" => "INVALID_REQUEST",
        "TIMEOUT" => "TIMEOUT",
        "CANCELED" => "CANCELED",
        _ => "INTERNAL",
    }
}

fn random_token() -> String {
    let mut seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|value| value.as_nanos())
        .unwrap_or(0) as u64;
    seed ^= std::process::id() as u64;
    let mut out = String::new();
    for _ in 0..32 {
        seed = seed
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        let value = (seed >> 33) & 0xf;
        out.push(char::from_digit(value as u32, 16).unwrap_or('0'));
    }
    out
}

const BASE64: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn encode_base64(input: &[u8]) -> String {
    let mut out = String::new();
    for chunk in input.chunks(3) {
        let first = chunk[0];
        let second = *chunk.get(1).unwrap_or(&0);
        let third = *chunk.get(2).unwrap_or(&0);
        out.push(BASE64[(first >> 2) as usize] as char);
        out.push(BASE64[(((first & 0x03) << 4) | (second >> 4)) as usize] as char);
        if chunk.len() > 1 {
            out.push(BASE64[(((second & 0x0f) << 2) | (third >> 6)) as usize] as char);
        } else {
            out.push('=');
        }
        if chunk.len() > 2 {
            out.push(BASE64[(third & 0x3f) as usize] as char);
        } else {
            out.push('=');
        }
    }
    out
}

fn decode_base64(input: &str) -> Result<Vec<u8>, String> {
    let mut table = [255u8; 256];
    for (index, byte) in BASE64.iter().enumerate() {
        table[*byte as usize] = index as u8;
    }
    let mut out = Vec::new();
    let mut buffer = 0u32;
    let mut bits = 0u32;
    for byte in input.bytes() {
        if byte == b'=' {
            break;
        }
        let value = table[byte as usize];
        if value == 255 {
            return Err("plugin: invalid payload".to_string());
        }
        buffer = (buffer << 6) | value as u32;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push(((buffer >> bits) & 0xff) as u8);
        }
    }
    Ok(out)
}
