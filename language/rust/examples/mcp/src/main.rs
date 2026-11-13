use std::sync::Arc;
use std::time::Duration;

use praxo_core::adapters::mcp::{McpClient, McpHttpRequest, McpHttpResponse, McpHttpTransport};
use praxo_core::errors::Result;
use serde_json::{json, Map, Value};

struct InProcessTransport;

impl McpHttpTransport for InProcessTransport {
    fn post(&self, request: McpHttpRequest) -> Result<McpHttpResponse> {
        let message = &request.message;
        let method = message
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let id = message.get("id").cloned().unwrap_or(Value::Null);
        if id.is_null() {
            return Ok(McpHttpResponse {
                status: 202,
                content_type: "application/json".to_string(),
                body: String::new(),
                session_id: None,
            });
        }
        let params = message.get("params").cloned().unwrap_or(Value::Null);
        let result = match method {
            "initialize" => json!({
                "protocolVersion": "2025-03-26",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "example-mcp", "version": "1.0.0"},
            }),
            "tools/list" => json!({"tools": tools()}),
            "tools/call" => call_tool(&params),
            _ => {
                return Ok(error_response(id, -32601, "method not found"));
            }
        };
        Ok(McpHttpResponse {
            status: 200,
            content_type: "application/json".to_string(),
            body: json!({"jsonrpc": "2.0", "id": id, "result": result}).to_string(),
            session_id: None,
        })
    }
}

fn tools() -> Value {
    json!([
        {
            "name": "echo",
            "description": "Echo input",
            "inputSchema": {
                "type": "object",
                "properties": {"text": {"type": "string"}},
                "required": ["text"],
            },
        },
        {
            "name": "add",
            "description": "Add two integers",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "a": {"type": "integer"},
                    "b": {"type": "integer"},
                },
                "required": ["a", "b"],
            },
        },
    ])
}

fn call_tool(params: &Value) -> Value {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let arguments = params
        .get("arguments")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    match name {
        "echo" => json!({
            "content": [{
                "type": "text",
                "text": arguments.get("text").and_then(Value::as_str).unwrap_or_default(),
            }],
            "isError": false,
        }),
        "add" => {
            let a = arguments
                .get("a")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            let b = arguments
                .get("b")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            json!({
                "content": [{"type": "text", "text": (a + b).to_string()}],
                "structuredContent": {"sum": a + b},
                "isError": false,
            })
        }
        _ => json!({
            "content": [{"type": "text", "text": "unknown tool"}],
            "isError": true,
        }),
    }
}

fn error_response(id: Value, code: i64, message: &str) -> McpHttpResponse {
    McpHttpResponse {
        status: 200,
        content_type: "application/json".to_string(),
        body: json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": {"code": code, "message": message},
        })
        .to_string(),
        session_id: None,
    }
}

fn main() {
    let transport = Arc::new(InProcessTransport);
    let client =
        McpClient::connect_http_with_timeout(transport, Duration::from_secs(2)).expect("connect");
    let tools = client.list_tools().expect("list tools");
    let mut arguments = Map::new();
    arguments.insert("a".to_string(), json!(2));
    arguments.insert("b".to_string(), json!(3));
    let result = client.call_tool("add", arguments).expect("call tool");
    let names = tools
        .iter()
        .map(|tool| tool.name.as_str())
        .collect::<Vec<_>>()
        .join(",");
    let sum = result
        .get("sum")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    client.close();

    assert_eq!(names, "add,echo");
    assert_eq!(sum, 5);
    println!("mcp test: ok");
}
