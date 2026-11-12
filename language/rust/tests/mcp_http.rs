use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use praxo_core::adapters::mcp::{
    McpClient, McpHttpRequest, McpHttpResponse, McpHttpTransport,
};
use praxo_core::errors::Result;
use serde_json::{json, Map, Value};

#[derive(Default)]
struct FakeTransport {
    requests: Mutex<Vec<McpHttpRequest>>,
    sse: AtomicBool,
    deleted: AtomicBool,
}

impl McpHttpTransport for FakeTransport {
    fn post(&self, request: McpHttpRequest) -> Result<McpHttpResponse> {
        self.requests.lock().unwrap().push(request.clone());
        let method = request
            .message
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or("");
        match method {
            "initialize" => Ok(response(
                200,
                "application/json",
                json!({
                    "jsonrpc": "2.0",
                    "id": request.message["id"],
                    "result": {
                        "protocolVersion": "2025-03-26",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "fake-http", "version": "1"},
                    },
                }),
                Some("sess-1"),
            )),
            "notifications/initialized" => Ok(response(202, "application/json", Value::Null, None)),
            "tools/list" => Ok(response(
                200,
                "application/json",
                json!({
                    "jsonrpc": "2.0",
                    "id": request.message["id"],
                    "result": {
                        "tools": [{
                            "name": "echo",
                            "description": "Echo input",
                            "inputSchema": {
                                "type": "object",
                                "properties": {"text": {"type": "string"}},
                                "required": ["text"],
                            },
                        }],
                    },
                }),
                None,
            )),
            "tools/call" => {
                let body = json!({
                    "jsonrpc": "2.0",
                    "id": request.message["id"],
                    "result": {
                        "content": [{
                            "type": "text",
                            "text": if self.sse.load(Ordering::SeqCst) {
                                "sse-ok"
                            } else {
                                "http-ok"
                            },
                        }],
                    },
                });
                if self.sse.load(Ordering::SeqCst) {
                    Ok(response(
                        200,
                        "text/event-stream",
                        json!({
                            "jsonrpc": "2.0",
                            "id": request.message["id"],
                            "result": {
                                "content": [{"type": "text", "text": "sse-ok"}],
                            },
                        }),
                        None,
                    ))
                } else {
                    Ok(response(200, "application/json", body, None))
                }
            }
            _ => Ok(response(
                200,
                "application/json",
                json!({"jsonrpc": "2.0", "id": request.message["id"], "result": {}}),
                None,
            )),
        }
    }

    fn delete(&self, _session_id: &str, _protocol_version: &str) -> Result<()> {
        self.deleted.store(true, Ordering::SeqCst);
        Ok(())
    }
}

fn response(
    status: u16,
    content_type: &str,
    value: Value,
    session_id: Option<&str>,
) -> McpHttpResponse {
    McpHttpResponse {
        status,
        content_type: content_type.to_string(),
        body: if content_type.contains("text/event-stream") {
            format!("event: message\ndata: {}\n\n", value)
        } else if value.is_null() {
            String::new()
        } else {
            value.to_string()
        },
        session_id: session_id.map(str::to_string),
    }
}

#[test]
fn http_handshake_list_call_and_delete() -> Result<()> {
    let transport = Arc::new(FakeTransport::default());
    let client = McpClient::connect_http(transport.clone())?;
    assert_eq!(client.protocol_version(), "2025-03-26");
    let tools = client.list_tools()?;
    assert_eq!(tools.len(), 1);
    assert_eq!(tools[0].name, "echo");
    let result = client.call_tool("echo", Map::from_iter([("text".to_string(), json!("hi"))]))?;
    assert_eq!(result, json!("http-ok"));
    client.close();
    assert!(transport.deleted.load(Ordering::SeqCst));
    let requests = transport.requests.lock().unwrap();
    let listed = requests
        .iter()
        .find(|request| request.message.get("method") == Some(&json!("tools/list")))
        .expect("tools/list request");
    assert_eq!(listed.session_id, "sess-1");
    assert_eq!(listed.protocol_version, "2025-03-26");
    Ok(())
}

#[test]
fn http_parses_sse_response() -> Result<()> {
    let transport = Arc::new(FakeTransport::default());
    transport.sse.store(true, Ordering::SeqCst);
    let client = McpClient::connect_http(transport)?;
    let result = client.call_tool("echo", Map::new())?;
    assert_eq!(result, json!("sse-ok"));
    Ok(())
}
