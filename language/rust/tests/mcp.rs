use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime};

use praxo_core::errors::PraxoError;
use praxo_core::mcp::{McpClient, McpServerConfig};
use praxo_core::tool::Registry;
use serde_json::{json, Map, Value};

fn server(mode: &str, marker: Option<&Path>) -> McpServerConfig {
    let mut config = McpServerConfig::new(env!("CARGO_BIN_EXE_fake_mcp_server")).arg(mode);
    if let Some(marker) = marker {
        config = config.arg(marker.to_string_lossy().to_string());
    }
    config
}

fn temp_marker() -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|value| value.as_nanos())
        .unwrap_or(0);
    std::env::temp_dir().join(format!("praxo-mcp-{}-{nanos}.txt", std::process::id()))
}

fn code(error: &PraxoError) -> &str {
    error.code
}

#[test]
fn handshake_lists_paginated_tools_and_preserves_schema() {
    let client = McpClient::connect(server("default", None)).expect("connect");
    assert_eq!(client.protocol_version(), "2024-11-05");
    assert_eq!(client.server_info()["name"], json!("fake-mcp"));
    let tools = client.list_tools().expect("list tools");
    assert_eq!(
        tools
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>(),
        vec!["add", "echo", "fail", "multi"]
    );
    let echo = tools.iter().find(|tool| tool.name == "echo").expect("echo");
    assert_eq!(echo.description, "Echo input");
    assert_eq!(
        Value::Object(echo.input_schema.clone()),
        json!({
            "type": "object",
            "properties": {"text": {"type": "string"}},
            "required": ["text"],
        })
    );
    assert_eq!(
        Value::Object(echo.spec().parameters.unwrap()),
        Value::Object(echo.input_schema.clone())
    );
    client.close();
}

#[test]
fn rejects_repeated_tool_pagination_cursor() {
    let client = McpClient::connect(server("repeated-cursor", None)).expect("connect");
    let error = client.list_tools().expect_err("repeated cursor");
    assert_eq!(code(&error), "MCP_PAGINATION");
    client.close();
}

#[test]
fn rejects_duplicate_tool_names() {
    let client = McpClient::connect(server("duplicate-name", None)).expect("connect");
    let error = client.list_tools().expect_err("duplicate name");
    assert_eq!(code(&error), "MCP_DUPLICATE_TOOL");
    client.close();
}

#[test]
fn maps_structured_and_text_tool_results() {
    let client = McpClient::connect(server("default", None)).expect("connect");
    let echo = client
        .call_tool(
            "echo",
            Map::from_iter([("text".to_string(), json!("hello"))]),
        )
        .expect("echo");
    assert_eq!(echo, json!("hello"));
    let add = client
        .call_tool(
            "add",
            Map::from_iter([("a".to_string(), json!(1)), ("b".to_string(), json!(2))]),
        )
        .expect("add");
    assert_eq!(add, json!({"sum": 3}));
    let multi = client.call_tool("multi", Map::new()).expect("multi");
    assert_eq!(multi, json!(["one", "two"]));
    let error = client
        .call_tool("fail", Map::new())
        .expect_err("tool error");
    assert_eq!(code(&error), "MCP_TOOL_ERROR");
    assert!(error.message.contains("boom"));
    client.close();
}

#[test]
fn registers_tools_through_the_core_registry() {
    let client = McpClient::connect(server("default", None)).expect("connect");
    let mut registry = Registry::new();
    let adapters = client.register_tools(&mut registry).expect("register");
    assert_eq!(registry.len(), 4);
    assert_eq!(
        adapters
            .iter()
            .map(|tool| tool.name().to_string())
            .collect::<Vec<_>>(),
        vec!["add", "echo", "fail", "multi"]
    );
    let echo = registry.get("echo").expect("registry echo");
    assert_eq!(
        echo.invoke(&Map::from_iter([("text".to_string(), json!("registered"))]))
            .expect("invoke"),
        json!("registered")
    );
    client.close();
}

#[test]
fn closes_the_child_process_and_refuses_later_calls() {
    let client = McpClient::connect(server("default", None)).expect("connect");
    assert!(client.is_running());
    assert!(client.pid().is_some());
    client.close();
    assert!(!client.is_running());
    let error = client.list_tools().expect_err("closed client");
    assert_eq!(code(&error), "MCP_CLOSED");
    client.close();
}

#[test]
fn times_out_and_sends_a_cancellation_notification() {
    let marker = temp_marker();
    let client = McpClient::connect(server("hang", Some(&marker))).expect("connect");
    client.list_tools().expect("list tools");
    let error = client
        .call_tool_with_timeout("hang", Map::new(), Some(Duration::from_millis(150)))
        .expect_err("timeout");
    assert_eq!(code(&error), "MCP_TIMEOUT");
    let started = Instant::now();
    while started.elapsed() < Duration::from_secs(2) {
        if fs::read_to_string(&marker)
            .map(|text| text.contains("cancelled"))
            .unwrap_or(false)
        {
            break;
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    assert!(fs::read_to_string(&marker)
        .map(|text| text.contains("cancelled"))
        .unwrap_or(false));
    client.close();
    let _ = fs::remove_file(marker);
}
