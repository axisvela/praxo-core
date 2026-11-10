use std::fs::OpenOptions;
use std::io::{self, BufRead, Write};
use std::path::PathBuf;

use serde_json::{json, Map, Value};

const PROTOCOL_VERSION: &str = "2024-11-05";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mode = args
        .first()
        .cloned()
        .unwrap_or_else(|| "default".to_string());
    let marker = args.get(1).map(PathBuf::from);
    let stdin = io::stdin();
    let mut initialized = false;
    for line in stdin.lock().lines() {
        let Ok(line) = line else {
            break;
        };
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let Ok(message) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let method = message.get("method").and_then(Value::as_str).unwrap_or("");
        let id = message.get("id").cloned();
        match method {
            "initialize" => {
                respond(
                    id,
                    json!({
                        "protocolVersion": PROTOCOL_VERSION,
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "fake-mcp", "version": "1.0.0"},
                    }),
                );
            }
            "notifications/initialized" => initialized = true,
            "notifications/cancelled" => {
                if let Some(path) = &marker {
                    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
                        let _ = writeln!(file, "cancelled");
                    }
                }
            }
            "tools/list" => {
                if !initialized {
                    error(id, -32002, "not initialized");
                    continue;
                }
                let params = message
                    .get("params")
                    .and_then(Value::as_object)
                    .cloned()
                    .unwrap_or_default();
                respond(id, list_tools(&mode, &params));
            }
            "tools/call" => {
                if !initialized {
                    error(id, -32002, "not initialized");
                    continue;
                }
                let params = message
                    .get("params")
                    .and_then(Value::as_object)
                    .cloned()
                    .unwrap_or_default();
                let name = params.get("name").and_then(Value::as_str).unwrap_or("");
                if mode == "hang" && name == "hang" {
                    continue;
                }
                respond(id, call_tool(&params));
            }
            _ => {
                if id.is_some() {
                    error(id, -32601, "method not found");
                }
            }
        }
    }
}

fn list_tools(mode: &str, params: &Map<String, Value>) -> Value {
    let cursor = params.get("cursor").and_then(Value::as_str).unwrap_or("");
    if mode == "repeated-cursor" {
        let label = if cursor.is_empty() { "start" } else { cursor };
        return json!({
            "tools": [generic_tool(&format!("loop-{label}"))],
            "nextCursor": "loop",
        });
    }
    if mode == "duplicate-name" {
        if cursor.is_empty() {
            return json!({
                "tools": [generic_tool("dup")],
                "nextCursor": "page-2",
            });
        }
        return json!({"tools": [generic_tool("dup")]});
    }
    if mode == "hang" {
        return json!({"tools": [tool(
            "hang",
            "Never responds",
            json!({"type": "object", "properties": {}}),
        )]});
    }
    if cursor.is_empty() {
        return json!({
            "tools": [
                tool(
                    "echo",
                    "Echo input",
                    json!({
                        "type": "object",
                        "properties": {"text": {"type": "string"}},
                        "required": ["text"],
                    }),
                ),
                tool(
                    "add",
                    "Add two integers",
                    json!({
                        "type": "object",
                        "properties": {
                            "a": {"type": "integer"},
                            "b": {"type": "integer"},
                        },
                        "required": ["a", "b"],
                    }),
                ),
            ],
            "nextCursor": "page-2",
        });
    }
    if cursor == "page-2" {
        return json!({
            "tools": [
                tool(
                    "fail",
                    "Always fails",
                    json!({"type": "object", "properties": {}}),
                ),
                tool(
                    "multi",
                    "Return two text blocks",
                    json!({"type": "object", "properties": {}}),
                ),
            ],
        });
    }
    json!({"tools": []})
}

fn tool(name: &str, description: &str, input_schema: Value) -> Value {
    json!({
        "name": name,
        "description": description,
        "inputSchema": input_schema,
    })
}

fn generic_tool(name: &str) -> Value {
    tool(name, "generic", json!({"type": "object", "properties": {}}))
}

fn call_tool(params: &Map<String, Value>) -> Value {
    let name = params.get("name").and_then(Value::as_str).unwrap_or("");
    let arguments = params
        .get("arguments")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    match name {
        "echo" => json!({
            "content": [{"type": "text", "text": arguments.get("text").and_then(Value::as_str).unwrap_or("")}],
            "isError": false,
        }),
        "add" => {
            let a = arguments.get("a").and_then(Value::as_i64).unwrap_or(0);
            let b = arguments.get("b").and_then(Value::as_i64).unwrap_or(0);
            json!({
                "content": [{"type": "text", "text": (a + b).to_string()}],
                "structuredContent": {"sum": a + b},
                "isError": false,
            })
        }
        "multi" => json!({
            "content": [
                {"type": "text", "text": "one"},
                {"type": "text", "text": "two"},
            ],
            "isError": false,
        }),
        "fail" => json!({
            "content": [{"type": "text", "text": "boom"}],
            "isError": true,
        }),
        _ => json!({
            "content": [{"type": "text", "text": format!("unknown tool {name}")}],
            "isError": true,
        }),
    }
}

fn respond(id: Option<Value>, result: Value) {
    write_message(json!({"jsonrpc": "2.0", "id": id, "result": result}));
}

fn error(id: Option<Value>, code: i64, message: &str) {
    write_message(json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": code, "message": message},
    }));
}

fn write_message(message: Value) {
    let mut stdout = io::stdout();
    let _ = writeln!(stdout, "{message}");
    let _ = stdout.flush();
}
