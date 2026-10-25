from __future__ import annotations

import json
import re
import uuid
from dataclasses import dataclass, field
from typing import Any

_DSML_INVOKE_RE = re.compile(r'<｜｜DSML｜｜invoke\s+name="([^"]+)"\s*>')
_DSML_PARAM_RE = re.compile(
    r'(?s)<｜｜DSML｜｜parameter\s+name="([^"]+)"'
    r'(?:\s+string="([^"]+)")?\s*>(.*?)</｜｜DSML｜｜parameter>'
)
_DSML_SINGULAR_RE = re.compile(
    r'(?s)<｜｜DSML｜｜tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</｜｜DSML｜｜tool_call>'
)
_XML_TOOL_RE = re.compile(
    r'(?s)<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>'
)
_INVOKE_NAME_RE = re.compile(r'<tool_name>\s*([^<]+?)\s*</tool_name>')
_INVOKE_ATTR_RE = re.compile(r'(?s)<parameters\s+actual="(.*?)">\s*</parameters>')
_INVOKE_BODY_RE = re.compile(r'(?s)<parameters>\s*(\{.*?)\s*</parameters>')
_TAG_TOOL_RE = re.compile(
    r'(?s)<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)'
)
_PLAIN_TOOL_RE = re.compile(r'(?m)^\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*$')
_TODO_RE = re.compile(r'(?s)<todo_(\w+?)>(.*?)</todo_\w+>')
_SKILL_RE = re.compile(r'(?s)<skill\.install\s+([^>]*)>(.*?)</skill\.install>')
_EXCESS_NEWLINES_RE = re.compile(r'\n{3,}')

_STRIP_RES = (
    re.compile(
        r'(?s)<｜｜DSML｜｜tool_calls>.*?(?:</｜｜DSML｜｜tool_calls>|$)'
    ),
    re.compile(
        r'(?s)<｜｜DSML｜｜tool_call\s+name="[^"]+"\s*>.*?'
        r'(?:</｜｜DSML｜｜tool_call>|$)'
    ),
    re.compile(r'(?s)<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)'),
    re.compile(r'(?s)<tool_call_invoke>.*?(?:</tool_call_invoke>|$)'),
    re.compile(
        r'(?s)<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?'
        r'(?:</[a-zA-Z][\w.-]*>|$)'
    ),
)


@dataclass
class ToolCall:
    call_id: str
    name: str
    operation: str = ""
    resource: str = ""
    risk: str = ""
    reason: str = ""
    idempotency_key: str = ""
    input: dict[str, Any] = field(default_factory=dict)


def parse_tool_call(content: str) -> ToolCall | None:
    call = _parse_json_call(content)
    if call is not None:
        return _with_id(call)
    for parser in (
        _parse_dsml,
        _parse_xml,
        _parse_invoke,
        _parse_tag,
        _parse_todo,
        _parse_skill_install,
        _parse_plain,
    ):
        call = parser(content)
        if call is not None:
            return _with_id(call)
    return None


def strip_tool_call_markup(content: str) -> str:
    out = content
    for pattern in _STRIP_RES:
        out = pattern.sub("", out)
    out = _EXCESS_NEWLINES_RE.sub("\n\n", out)
    return out.strip()


def parse_input_json(raw: str) -> dict[str, Any] | None:
    try:
        value = json.loads(raw.strip())
        return value if isinstance(value, dict) else None
    except (ValueError, TypeError):
        pass
    try:
        value = json.loads(raw.replace("\\", "\\\\").strip())
        return value if isinstance(value, dict) else None
    except (ValueError, TypeError):
        return None


def _parse_json_call(content: str) -> ToolCall | None:
    try:
        value = json.loads(content)
    except (ValueError, TypeError):
        return None
    if not isinstance(value, dict) or not value.get("name"):
        return None
    input_value = value.get("input")
    return ToolCall(
        call_id="",
        name=value["name"],
        operation=value.get("operation", ""),
        resource=value.get("resource", ""),
        risk=value.get("risk", ""),
        reason=value.get("reason", ""),
        idempotency_key=value.get("idempotency_key", ""),
        input=input_value if isinstance(input_value, dict) else {},
    )


def _parse_dsml(content: str) -> ToolCall | None:
    if "<｜｜DSML｜｜" not in content:
        return None
    if "<｜｜DSML｜｜tool_calls>" not in content:
        match = _DSML_SINGULAR_RE.search(content)
        if match is None:
            return None
        parsed = parse_input_json(match.group(2))
        return ToolCall(
            call_id="",
            name=match.group(1),
            input=parsed or {"content": match.group(2).strip()},
        )
    invoke = _DSML_INVOKE_RE.search(content)
    if invoke is None:
        return None
    input_value: dict[str, Any] = {}
    for match in _DSML_PARAM_RE.finditer(content):
        raw = match.group(3).strip()
        try:
            input_value[match.group(1)] = json.loads(raw)
        except (ValueError, TypeError):
            input_value[match.group(1)] = raw
    return ToolCall(call_id="", name=invoke.group(1), input=input_value)


def _parse_xml(content: str) -> ToolCall | None:
    matches = list(_XML_TOOL_RE.finditer(content))
    if not matches:
        return None
    match = matches[-1]
    parsed = parse_input_json(match.group(2))
    if parsed is None:
        return None
    return ToolCall(call_id="", name=match.group(1), input=parsed)


def _parse_invoke(content: str) -> ToolCall | None:
    if "<tool_call_invoke>" not in content:
        return None
    name = _INVOKE_NAME_RE.search(content)
    if name is None:
        return None
    raw = ""
    attr = _INVOKE_ATTR_RE.search(content)
    if attr is not None:
        raw = attr.group(1).replace('\\"', '"')
    else:
        body = _INVOKE_BODY_RE.search(content)
        if body is not None:
            raw = body.group(1)
    input_value: dict[str, Any] = {}
    if raw.strip():
        parsed = parse_input_json(raw)
        if parsed is None:
            return None
        input_value = parsed
    return ToolCall(call_id="", name=name.group(1).strip(), input=input_value)


def _parse_tag(content: str) -> ToolCall | None:
    matches = list(_TAG_TOOL_RE.finditer(content))
    if not matches:
        return None
    match = matches[-1]
    parsed = parse_input_json(match.group(2))
    if parsed is None:
        return None
    return ToolCall(call_id="", name=match.group(1), input=parsed)


def _parse_todo(content: str) -> ToolCall | None:
    if "<todo_" not in content:
        return None
    match = _TODO_RE.search(content)
    if match is None:
        return None
    raw = match.group(2).strip()
    try:
        parsed = json.loads(raw)
    except (ValueError, TypeError):
        parsed = None
    if isinstance(parsed, dict):
        return ToolCall(call_id="", name=f"todo.{match.group(1)}", input=parsed)
    return ToolCall(
        call_id="",
        name=f"todo.{match.group(1)}",
        input={"content": raw},
    )


def _parse_skill_install(content: str) -> ToolCall | None:
    if "<skill.install" not in content:
        return None
    match = _SKILL_RE.search(content)
    if match is None:
        return None
    input_value: dict[str, Any] = {}
    for pair in match.group(1).strip().split(" "):
        if not pair:
            continue
        parts = pair.split("=", 1)
        if len(parts) == 2:
            key = parts[0].strip('"')
            value = parts[1].strip(' "\\')
            input_value[key] = value
    if not input_value.get("url"):
        input_value["name"] = match.group(2).strip()
    return ToolCall(call_id="", name="skill.install", input=input_value)


def _parse_plain(content: str) -> ToolCall | None:
    matches = list(_PLAIN_TOOL_RE.finditer(content))
    if not matches:
        return None
    match = matches[-1]
    if "." not in match.group(1):
        return None
    parsed = parse_input_json(match.group(2))
    if parsed is None:
        return None
    return ToolCall(call_id="", name=match.group(1), input=parsed)


def _with_id(call: ToolCall) -> ToolCall:
    call.call_id = f"tc-{uuid.uuid4().hex[:16]}"
    return call
