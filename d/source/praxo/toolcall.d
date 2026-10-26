module praxo.toolcall;

import std.string : indexOf, strip, replace;
import praxo.json : JSONValue, JSONType;
import praxo.json;

class ParsedToolCall {
    string callId = "";
    string name = "";
    JSONValue input;
    string operation = "";
    string resource = "";
    string risk = "";
    string reason = "";
    string idempotencyKey = "";
}

ParsedToolCall parseToolCall(string content) {
    auto call = parseJsonCall(content);
    if (call is null) call = parseXml(content);
    if (call is null) call = parseTag(content);
    if (call is null) call = parsePlain(content);
    return call;
}

string stripMarkup(string content) {
    auto output = content;
    while (true) {
        auto start = output.indexOf("<tool_call");
        if (start < 0) break;
        auto end = output.indexOf("</tool_call>", start);
        output = end < 0 ? output[0 .. start] :
            output[0 .. start] ~ output[end + "</tool_call>".length .. $];
    }
    while (true) {
        auto start = output.indexOf("<tool_call_invoke>");
        if (start < 0) break;
        auto end = output.indexOf("</tool_call_invoke>", start);
        output = end < 0 ? output[0 .. start] :
            output[0 .. start] ~ output[end + "</tool_call_invoke>".length .. $];
    }
    while (true) {
        auto start = output.indexOf("<");
        if (start < 0) break;
        auto close = output.indexOf(">", start);
        if (close < 0) break;
        auto name = output[start + 1 .. close];
        if (name.indexOf(".") < 0) {
            output = output[0 .. start + 1] ~ output[start + 1 .. $];
            break;
        }
        auto closing = "</" ~ name ~ ">";
        auto end = output.indexOf(closing, close + 1);
        output = end < 0 ? output[0 .. start] : output[0 .. start] ~ output[end + closing.length .. $];
    }
    while (output.indexOf("\n\n\n") >= 0) output = output.replace("\n\n\n", "\n\n");
    return output.strip();
}

JSONValue parseInputJson(string raw) {
    auto value = parse(raw.strip());
    if (value.type == JSONType.object) return value;
    auto escaped = raw.replace("\\", "\\\\").strip();
    value = parse(escaped);
    return value.type == JSONType.object ? value : JSONValue(null);
}

private ParsedToolCall parseJsonCall(string content) {
    JSONValue value;
    try {
        value = parse(content);
    } catch (Exception) {
        return null;
    }
    if (value.type != JSONType.object) return null;
    auto name = getString(value, "name");
    if (name is null || name.length == 0) return null;
    auto call = new ParsedToolCall();
    call.name = name;
    call.input = get(value, "input");
    if (call.input.type != JSONType.object) call.input = JSONValue(cast(JSONValue[string]) null);
    call.operation = getString(value, "operation");
    call.resource = getString(value, "resource");
    call.risk = getString(value, "risk");
    call.reason = getString(value, "reason");
    call.idempotencyKey = getString(value, "idempotency_key");
    return call;
}

private ParsedToolCall parseXml(string content) {
    auto open = content.indexOf("<tool_call");
    if (open < 0) return null;
    auto nameMarker = content.indexOf("name=\"", open);
    if (nameMarker < 0) return null;
    auto nameStart = nameMarker + 6;
    auto nameEnd = content.indexOf("\"", nameStart);
    if (nameEnd < 0) return null;
    auto bodyStart = content.indexOf(">", nameEnd);
    if (bodyStart < 0) return null;
    bodyStart++;
    auto bodyEnd = content.indexOf("</tool_call>", bodyStart);
    if (bodyEnd < 0) return null;
    auto input = parseInputJson(content[bodyStart .. bodyEnd]);
    if (input.type != JSONType.object) return null;
    auto call = new ParsedToolCall();
    call.name = content[nameStart .. nameEnd];
    call.input = input;
    return call;
}

private ptrdiff_t balancedObject(string content, size_t start) {
    if (start >= content.length || content[start] != '{') return -1;
    int depth = 0;
    bool inString = false;
    bool escaped = false;
    foreach (index, c; content[start .. $]) {
        if (inString) {
            if (escaped) escaped = false;
            else if (c == '\\') escaped = true;
            else if (c == '"') inString = false;
        } else {
            if (c == '"') inString = true;
            else if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) return cast(ptrdiff_t) (start + index + 1);
            }
        }
    }
    return -1;
}

private ParsedToolCall parseTag(string content) {
    auto open = content.indexOf("<");
    if (open < 0) return null;
    auto close = content.indexOf(">", open);
    if (close < 0) return null;
    auto name = content[open + 1 .. close];
    if (name.indexOf(".") < 0) return null;
    auto objectStart = content.indexOf("{", close + 1);
    if (objectStart < 0) return null;
    auto objectEnd = balancedObject(content, objectStart);
    if (objectEnd < 0) return null;
    auto input = parseInputJson(content[objectStart .. objectEnd]);
    if (input.type != JSONType.object) return null;
    auto call = new ParsedToolCall();
    call.name = name;
    call.input = input;
    return call;
}

private ParsedToolCall parsePlain(string content) {
    auto text = content.strip();
    auto space = text.indexOf(" ");
    if (space < 0) return null;
    auto name = text[0 .. space];
    if (name.indexOf(".") < 0) return null;
    auto objectStart = text.indexOf("{", space);
    if (objectStart < 0) return null;
    auto objectEnd = balancedObject(text, objectStart);
    if (objectEnd < 0) return null;
    auto input = parseInputJson(text[objectStart .. objectEnd]);
    if (input.type != JSONType.object) return null;
    auto call = new ParsedToolCall();
    call.name = name;
    call.input = input;
    return call;
}
