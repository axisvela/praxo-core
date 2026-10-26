const std = @import("std");
const json = @import("json.zig");

pub const ParsedToolCall = struct {
    call_id: []const u8 = "",
    name: []const u8 = "",
    input: json.Json,
    operation: []const u8 = "",
    resource: []const u8 = "",
    risk: []const u8 = "",
    reason: []const u8 = "",
    idempotency_key: []const u8 = "",
};

const Allocator = std.mem.Allocator;

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r\n");
}

fn baseCall(name: []const u8, input: json.Json) ParsedToolCall {
    return .{ .name = name, .input = input };
}

pub fn parseInputJson(allocator: Allocator, raw: []const u8) !?json.Json {
    if (json.parse(allocator, trim(raw))) |value| {
        if (value == .object) return value;
    } else |_| {}
    var escaped = std.array_list.Managed(u8).init(allocator);
    defer escaped.deinit();
    for (trim(raw)) |byte| {
        if (byte == '\\') try escaped.append('\\');
        try escaped.append(byte);
    }
    if (json.parse(allocator, escaped.items)) |value| {
        if (value == .object) return value;
    } else |_| {}
    return null;
}

fn parseJsonCall(allocator: Allocator, content: []const u8) !?ParsedToolCall {
    const value = json.parse(allocator, content) catch return null;
    if (value != .object) return null;
    const name = json.string(value, "name") orelse return null;
    if (name.len == 0) return null;
    const input = if (json.get(value, "input")) |item| item else json.Json{ .object = .empty };
    if (input != .object) return null;
    return .{
        .name = name,
        .input = input,
        .operation = json.string(value, "operation") orelse "",
        .resource = json.string(value, "resource") orelse "",
        .risk = json.string(value, "risk") orelse "",
        .reason = json.string(value, "reason") orelse "",
        .idempotency_key = json.string(value, "idempotency_key") orelse "",
    };
}

fn parseXml(allocator: Allocator, content: []const u8) !?ParsedToolCall {
    const open = std.mem.indexOf(u8, content, "<tool_call") orelse return null;
    const name_marker = std.mem.indexOfPos(u8, content, open, "name=\"") orelse return null;
    const name_start = name_marker + 6;
    const name_end = std.mem.indexOfPos(u8, content, name_start, "\"") orelse return null;
    const body_start = (std.mem.indexOfPos(u8, content, name_end, ">") orelse return null) + 1;
    const body_end = std.mem.indexOfPos(u8, content, body_start, "</tool_call>") orelse return null;
    const input = try parseInputJson(allocator, content[body_start..body_end]) orelse return null;
    return baseCall(content[name_start..name_end], input);
}

fn balancedObject(content: []const u8, start: usize) ?usize {
    if (start >= content.len or content[start] != '{') return null;
    var depth: usize = 0;
    var in_string = false;
    var escaped = false;
    var index = start;
    while (index < content.len) : (index += 1) {
        const byte = content[index];
        if (in_string) {
            if (escaped) {
                escaped = false;
            } else if (byte == '\\') {
                escaped = true;
            } else if (byte == '"') {
                in_string = false;
            }
        } else {
            if (byte == '"') in_string = true
            else if (byte == '{') depth += 1
            else if (byte == '}') {
                depth -= 1;
                if (depth == 0) return index + 1;
            }
        }
    }
    return null;
}

fn parseTag(allocator: Allocator, content: []const u8) !?ParsedToolCall {
    const open = std.mem.indexOf(u8, content, "<") orelse return null;
    const close = std.mem.indexOfPos(u8, content, open, ">") orelse return null;
    const name = content[open + 1 .. close];
    if (std.mem.indexOfScalar(u8, name, '.') == null) return null;
    const object_start = std.mem.indexOfPos(u8, content, close + 1, "{") orelse return null;
    const object_end = balancedObject(content, object_start) orelse return null;
    const input = try parseInputJson(allocator, content[object_start..object_end]) orelse return null;
    return baseCall(name, input);
}

fn parsePlain(allocator: Allocator, content: []const u8) !?ParsedToolCall {
    const text = trim(content);
    const space = std.mem.indexOfScalar(u8, text, ' ') orelse return null;
    const name = text[0..space];
    if (std.mem.indexOfScalar(u8, name, '.') == null) return null;
    const object_start = std.mem.indexOfScalarPos(u8, text, space, '{') orelse return null;
    const object_end = balancedObject(text, object_start) orelse return null;
    const input = try parseInputJson(allocator, text[object_start..object_end]) orelse return null;
    return baseCall(name, input);
}

pub fn parseToolCall(allocator: Allocator, content: []const u8) !?ParsedToolCall {
    var call = try parseJsonCall(allocator, content);
    if (call == null) call = try parseXml(allocator, content);
    if (call == null) call = try parseTag(allocator, content);
    if (call == null) call = try parsePlain(allocator, content);
    return call;
}

fn appendRange(out: *std.array_list.Managed(u8), text: []const u8, start: usize, end: usize) !void {
    if (end > start) try out.appendSlice(text[start..end]);
}

pub fn stripMarkup(allocator: Allocator, content: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    var index: usize = 0;
    while (index < content.len) {
        if (std.mem.startsWith(u8, content[index..], "<tool_call")) {
            const end = std.mem.indexOfPos(u8, content, index, "</tool_call>");
            index = if (end) |value| value + "</tool_call>".len else content.len;
        } else if (std.mem.startsWith(u8, content[index..], "<tool_call_invoke>")) {
            const end = std.mem.indexOfPos(u8, content, index, "</tool_call_invoke>");
            index = if (end) |value| value + "</tool_call_invoke>".len else content.len;
        } else if (content[index] == '<') {
            const close = std.mem.indexOfPos(u8, content, index, ">") orelse {
                try out.append(content[index]);
                index += 1;
                continue;
            };
            const name = content[index + 1 .. close];
            if (std.mem.indexOfScalar(u8, name, '.') != null) {
                const closing = std.mem.concat(allocator, u8, &.{ "</", name, ">" }) catch return error.OutOfMemory;
                defer allocator.free(closing);
                const end = std.mem.indexOfPos(u8, content, close + 1, closing);
                index = if (end) |value| value + closing.len else content.len;
            } else {
                try out.append(content[index]);
                index += 1;
            }
        } else {
            try out.append(content[index]);
            index += 1;
        }
    }
    var trimmed = std.mem.trim(u8, out.items, " \t\r\n");
    var collapsed = std.array_list.Managed(u8).init(allocator);
    var newlines: usize = 0;
    for (trimmed) |byte| {
        if (byte == '\n') {
            newlines += 1;
            if (newlines <= 2) try collapsed.append(byte);
        } else {
            newlines = 0;
            try collapsed.append(byte);
        }
    }
    trimmed = std.mem.trim(u8, collapsed.items, " \t\r\n");
    return allocator.dupe(u8, trimmed);
}

test "zig toolcall" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const call = try parseToolCall(arena.allocator(), "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}");
    try std.testing.expect(call != null);
    try std.testing.expectEqualStrings("echo", call.?.name);
    const stripped = try stripMarkup(arena.allocator(), "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world");
    try std.testing.expectEqualStrings("helloworld", stripped);
}
