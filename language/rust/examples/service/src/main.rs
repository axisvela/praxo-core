use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::model::{Message, Model, Request, Response};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{FuncTool, Registry};
use serde_json::{json, Value};

struct StubModel;

impl Model for StubModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        Ok(Response {
            message: Message::assistant("hello from the service", Vec::new()),
            ..Response::default()
        })
    }
}

struct ServicePolicy;

impl Hook for ServicePolicy {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("model generation")),
            "tool.invoke" if action.tool_name.as_deref() == Some("get_time") => {
                Ok(Decision::allow("get_time is permitted"))
            }
            "tool.invoke" => Ok(Decision::deny("only get_time is permitted")),
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn create_agent() -> Agent {
    let mut tools = Registry::new();
    tools.register(Arc::new(FuncTool::new(
        "get_time",
        "Return the current Unix timestamp.",
        |_args| {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            Ok(Value::String(now.to_string()))
        },
    )));
    let mut options = AgentOptions::new(Arc::new(StubModel));
    options.tools = Some(Arc::new(tools));
    options.system_prompt =
        "You are a concise service assistant. Use tools when they help.".to_string();
    options.max_steps = 4;
    options.allowed_tools = vec!["get_time".to_string()];
    options.policy = Some(Arc::new(ServicePolicy));
    Agent::new(options).expect("agent")
}

fn handle_request(
    agent: &Agent,
    tenant: &str,
    method: &str,
    path: &str,
    principal: Option<&str>,
    body: &str,
) -> (u16, Value) {
    if method == "GET" && path == "/healthz" {
        return (200, json!({"status": "ok"}));
    }
    if method != "POST" || path != "/run" {
        return (404, json!({"error": "not found"}));
    }
    let Some(principal) = principal.filter(|value| !value.is_empty()) else {
        return (401, json!({"error": "missing X-Praxo-Principal"}));
    };
    let payload: Value = match serde_json::from_str(body) {
        Ok(payload @ Value::Object(_)) => payload,
        _ => return (400, json!({"error": "invalid JSON body"})),
    };
    let prompt = payload.get("prompt").and_then(Value::as_str).unwrap_or("");
    if prompt.is_empty() {
        return (400, json!({"error": "prompt is required"}));
    }
    let mut session = Session::new(principal);
    session.tenant_id = tenant.to_string();
    session.workspace_id = "service".to_string();
    match agent.run(&session, prompt) {
        Ok(result) => (200, json!({"output": result.output})),
        Err(error) => (500, json!({"error": error.message})),
    }
}

fn find_header_end(buffer: &[u8]) -> Option<usize> {
    buffer.windows(4).position(|window| window == b"\r\n\r\n")
}

fn serve_client(mut stream: TcpStream, agent: &Agent, tenant: &str) -> std::io::Result<()> {
    let mut buffer = Vec::new();
    let mut chunk = [0u8; 1024];
    let header_end = loop {
        let read = stream.read(&mut chunk)?;
        if read == 0 {
            return Ok(());
        }
        buffer.extend_from_slice(&chunk[..read]);
        if let Some(position) = find_header_end(&buffer) {
            break position;
        }
        if buffer.len() > 65536 {
            return Ok(());
        }
    };
    let header = String::from_utf8_lossy(&buffer[..header_end]);
    let mut lines = header.split("\r\n");
    let mut request = lines.next().unwrap_or_default().split_whitespace();
    let method = request.next().unwrap_or_default();
    let path = request.next().unwrap_or_default();
    let mut principal = None;
    let mut content_length = 0usize;
    for line in lines {
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };
        let key = key.trim();
        let value = value.trim();
        if key.eq_ignore_ascii_case("X-Praxo-Principal") {
            principal = Some(value.to_string());
        } else if key.eq_ignore_ascii_case("Content-Length") {
            content_length = value.parse().unwrap_or(0);
        }
    }
    let mut body = buffer[header_end + 4..].to_vec();
    while body.len() < content_length {
        let read = stream.read(&mut chunk)?;
        if read == 0 {
            break;
        }
        body.extend_from_slice(&chunk[..read]);
    }
    let body = String::from_utf8_lossy(&body[..body.len().min(content_length)]);
    let (status, response) =
        handle_request(agent, tenant, method, path, principal.as_deref(), &body);
    let reason = match status {
        200 => "OK",
        400 => "Bad Request",
        401 => "Unauthorized",
        404 => "Not Found",
        _ => "Internal Server Error",
    };
    let encoded = response.to_string();
    write!(
        stream,
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\n\
         Content-Length: {}\r\nConnection: close\r\n\r\n{}",
        encoded.len(),
        encoded
    )?;
    Ok(())
}

fn serve(agent: Agent, tenant: &str) -> std::io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080")?;
    println!("listening on http://127.0.0.1:8080");
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let _ = serve_client(stream, &agent, tenant);
            }
            Err(error) => eprintln!("accept: {error}"),
        }
    }
    Ok(())
}

fn run_tests() {
    let agent = create_agent();
    let (status, _) = handle_request(&agent, "local", "GET", "/healthz", None, "");
    assert_eq!(status, 200);
    let (status, _) = handle_request(&agent, "local", "POST", "/run", None, r#"{"prompt":"hi"}"#);
    assert_eq!(status, 401);
    let (status, _) = handle_request(&agent, "local", "POST", "/run", Some("user-1"), "not json");
    assert_eq!(status, 400);
    let (status, body) = handle_request(
        &agent,
        "local",
        "POST",
        "/run",
        Some("user-1"),
        r#"{"prompt":"hi"}"#,
    );
    assert_eq!(status, 200);
    assert_eq!(body["output"], json!("hello from the service"));
}

fn main() {
    if std::env::args().any(|arg| arg == "--test") {
        run_tests();
        println!("service test: ok");
        return;
    }
    let tenant = std::env::var("PRAXO_TENANT").unwrap_or_else(|_| "local".to_string());
    if let Err(error) = serve(create_agent(), &tenant) {
        eprintln!("service: {error}");
        std::process::exit(1);
    }
}
