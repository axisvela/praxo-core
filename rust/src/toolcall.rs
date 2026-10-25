use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use regex::Regex;
use serde_json::{Map, Value};

#[derive(Debug, Clone, PartialEq)]
pub struct ParsedToolCall {
    pub call_id: String,
    pub name: String,
    pub operation: String,
    pub resource: String,
    pub risk: String,
    pub reason: String,
    pub idempotency_key: String,
    pub input: Map<String, Value>,
}

fn regex(slot: &'static OnceLock<Regex>, pattern: &str) -> &'static Regex {
    slot.get_or_init(|| Regex::new(pattern).expect("valid regex"))
}

fn dsml_invoke() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r#"<｜｜DSML｜｜invoke\s+name="([^"]+)"\s*>"#)
}

fn dsml_param() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(
        &RE,
        r#"(?s)<｜｜DSML｜｜parameter\s+name="([^"]+)"(?:\s+string="([^"]+)")?\s*>(.*?)</｜｜DSML｜｜parameter>"#,
    )
}

fn dsml_singular() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(
        &RE,
        r#"(?s)<｜｜DSML｜｜tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</｜｜DSML｜｜tool_call>"#,
    )
}

fn xml_tool() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r#"(?s)<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>"#)
}

fn invoke_name() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"<tool_name>\s*([^<]+?)\s*</tool_name>")
}

fn invoke_attr() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r#"(?s)<parameters\s+actual="(.*?)">\s*</parameters>"#)
}

fn invoke_body() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"(?s)<parameters>\s*(\{.*?)\s*</parameters>")
}

fn tag_tool() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(
        &RE,
        r"(?s)<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)",
    )
}

fn plain_tool() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"(?m)^\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*$")
}

fn todo() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"(?s)<todo_(\w+?)>(.*?)</todo_\w+>")
}

fn skill() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"(?s)<skill\.install\s+([^>]*)>(.*?)</skill\.install>")
}

fn excess_newlines() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    regex(&RE, r"\n{3,}")
}

fn strip_patterns() -> &'static Vec<Regex> {
    static RES: OnceLock<Vec<Regex>> = OnceLock::new();
    RES.get_or_init(|| {
        [
            r"<｜｜DSML｜｜tool_calls>.*?(?:</｜｜DSML｜｜tool_calls>|$)",
            r#"<｜｜DSML｜｜tool_call\s+name="[^"]+"\s*>.*?(?:</｜｜DSML｜｜tool_call>|$)"#,
            r#"<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)"#,
            r"(<tool_call_invoke>).*?(?:</tool_call_invoke>|$)",
            r"<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)",
        ]
        .iter()
        .map(|pattern| Regex::new(&format!("(?s){pattern}")).expect("valid regex"))
        .collect()
    })
}

pub fn parse(content: &str) -> Option<ParsedToolCall> {
    if let Some(call) = parse_json(content) {
        return Some(with_id(call));
    }
    for parser in [
        parse_dsml,
        parse_xml,
        parse_invoke,
        parse_tag,
        parse_todo,
        parse_skill_install,
        parse_plain,
    ] {
        if let Some(call) = parser(content) {
            return Some(with_id(call));
        }
    }
    None
}

pub fn strip_markup(content: &str) -> String {
    let mut out = content.to_string();
    for pattern in strip_patterns() {
        out = pattern.replace_all(&out, "").to_string();
    }
    excess_newlines().replace_all(&out, "\n\n").trim().to_string()
}

pub fn parse_input_json(raw: &str) -> Option<Map<String, Value>> {
    if let Ok(Value::Object(map)) = serde_json::from_str::<Value>(raw.trim()) {
        return Some(map);
    }
    let escaped = raw.replace('\\', "\\\\");
    if let Ok(Value::Object(map)) = serde_json::from_str::<Value>(escaped.trim()) {
        return Some(map);
    }
    None
}

fn parse_json(content: &str) -> Option<ParsedToolCall> {
    let value: Value = serde_json::from_str(content).ok()?;
    let map = value.as_object()?;
    let name = map.get("name")?.as_str()?;
    if name.is_empty() {
        return None;
    }
    let input = map
        .get("input")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    Some(ParsedToolCall {
        call_id: String::new(),
        name: name.to_string(),
        operation: text(map.get("operation")),
        resource: text(map.get("resource")),
        risk: text(map.get("risk")),
        reason: text(map.get("reason")),
        idempotency_key: text(map.get("idempotency_key")),
        input,
    })
}

fn parse_dsml(content: &str) -> Option<ParsedToolCall> {
    if !content.contains("<｜｜DSML｜｜") {
        return None;
    }
    if !content.contains("<｜｜DSML｜｜tool_calls>") {
        let capture = dsml_singular().captures(content)?;
        let raw = capture.get(2)?.as_str();
        let input = parse_input_json(raw)
            .unwrap_or_else(|| {
                let mut map = Map::new();
                map.insert("content".to_string(), Value::String(raw.trim().to_string()));
                map
            });
        return Some(basic(capture.get(1)?.as_str(), input));
    }
    let invoke = dsml_invoke().captures(content)?;
    let mut input = Map::new();
    for capture in dsml_param().captures_iter(content) {
        let raw = capture.get(3).map(|item| item.as_str()).unwrap_or("");
        let value = serde_json::from_str(raw)
            .unwrap_or_else(|_| Value::String(raw.trim().to_string()));
        input.insert(
            capture.get(1)?.as_str().to_string(),
            value,
        );
    }
    Some(basic(invoke.get(1)?.as_str(), input))
}

fn parse_xml(content: &str) -> Option<ParsedToolCall> {
    let mut last = None;
    for capture in xml_tool().captures_iter(content) {
        last = Some((
            capture.get(1)?.as_str().to_string(),
            capture.get(2)?.as_str().to_string(),
        ));
    }
    let (name, raw) = last?;
    Some(basic(&name, parse_input_json(&raw)?))
}

fn parse_invoke(content: &str) -> Option<ParsedToolCall> {
    if !content.contains("<tool_call_invoke>") {
        return None;
    }
    let name = invoke_name().captures(content)?.get(1)?.as_str().trim().to_string();
    let raw = if let Some(capture) = invoke_attr().captures(content) {
        capture.get(1)?.as_str().replace("\\\"", "\"")
    } else if let Some(capture) = invoke_body().captures(content) {
        capture.get(1)?.as_str().to_string()
    } else {
        String::new()
    };
    let input = if raw.trim().is_empty() {
        Map::new()
    } else {
        parse_input_json(&raw)?
    };
    Some(basic(&name, input))
}

fn parse_tag(content: &str) -> Option<ParsedToolCall> {
    let mut last = None;
    for capture in tag_tool().captures_iter(content) {
        last = Some((
            capture.get(1)?.as_str().to_string(),
            capture.get(2)?.as_str().to_string(),
        ));
    }
    let (name, raw) = last?;
    Some(basic(&name, parse_input_json(&raw)?))
}

fn parse_todo(content: &str) -> Option<ParsedToolCall> {
    if !content.contains("<todo_") {
        return None;
    }
    let capture = todo().captures(content)?;
    let raw = capture.get(2)?.as_str().trim();
    let input = parse_input_json(raw).unwrap_or_else(|| {
        let mut map = Map::new();
        map.insert("content".to_string(), Value::String(raw.to_string()));
        map
    });
    Some(basic(&format!("todo.{}", capture.get(1)?.as_str()), input))
}

fn parse_skill_install(content: &str) -> Option<ParsedToolCall> {
    if !content.contains("<skill.install") {
        return None;
    }
    let capture = skill().captures(content)?;
    let mut input = Map::new();
    for pair in capture.get(1)?.as_str().trim().split(' ') {
        if pair.is_empty() {
            continue;
        }
        let Some((key, value)) = pair.split_once('=') else {
            continue;
        };
        input.insert(
            key.trim_matches('"').to_string(),
            Value::String(value.trim_matches(|ch| ch == '"' || ch == ' ' || ch == '\\').to_string()),
        );
    }
    if !input.contains_key("url") {
        input.insert(
            "name".to_string(),
            Value::String(capture.get(2)?.as_str().trim().to_string()),
        );
    }
    Some(basic("skill.install", input))
}

fn parse_plain(content: &str) -> Option<ParsedToolCall> {
    let mut last = None;
    for capture in plain_tool().captures_iter(content) {
        last = Some((
            capture.get(1)?.as_str().to_string(),
            capture.get(2)?.as_str().to_string(),
        ));
    }
    let (name, raw) = last?;
    if !name.contains('.') {
        return None;
    }
    Some(basic(&name, parse_input_json(&raw)?))
}

fn basic(name: &str, input: Map<String, Value>) -> ParsedToolCall {
    ParsedToolCall {
        call_id: String::new(),
        name: name.to_string(),
        operation: String::new(),
        resource: String::new(),
        risk: String::new(),
        reason: String::new(),
        idempotency_key: String::new(),
        input,
    }
}

fn with_id(call: ParsedToolCall) -> ParsedToolCall {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    ParsedToolCall {
        call_id: format!("tc-{nanos}"),
        ..call
    }
}

fn text(value: Option<&Value>) -> String {
    value.and_then(Value::as_str).unwrap_or("").to_string()
}
