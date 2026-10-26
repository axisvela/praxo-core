const std = @import("std");
const json = @import("json.zig");

pub const SYSTEM = "system";
pub const USER = "user";
pub const ASSISTANT = "assistant";
pub const TOOL = "tool";
pub const stream_kinds = [_][]const u8{ "values", "updates", "messages", "tasks", "debug", "checkpoint" };

pub const ContentBlock = struct {
    type: []const u8 = "text",
    text: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    data: ?[]const u8 = null,
};

pub const ToolCall = struct {
    id: []const u8 = "",
    name: []const u8 = "",
    arguments: json.Json = .{ .object = .empty },
};

pub const Message = struct {
    role: []const u8,
    content: ?[]const u8 = null,
    content_blocks: []const ContentBlock = &.{},
    tool_calls: []const ToolCall = &.{},
    tool_id: ?[]const u8 = null,
};

pub const ToolSpec = struct {
    name: []const u8,
    description: []const u8 = "",
    parameters: ?json.Json = null,
    risk: ?[]const u8 = null,
};

pub const Usage = struct {
    input_tokens: i64 = 0,
    output_tokens: i64 = 0,
    cached_tokens: i64 = 0,
};

pub const Request = struct {
    messages: []const Message = &.{},
    tools: []const ToolSpec = &.{},
    tool_choice: ?[]const u8 = null,
    response_format: ?json.Json = null,
    temperature: f64 = 0,
};

pub const Response = struct {
    message: Message,
    usage: Usage = .{},
    finish_reason: ?[]const u8 = null,
};

pub const Session = struct {
    id: []const u8,
    messages: []const Message = &.{},
};

pub const RunResult = struct {
    run_id: []const u8 = "",
    output: []const u8 = "",
    steps: i64 = 0,
    usage: Usage = .{},
};

pub const MemoryRecord = struct {
    id: []const u8 = "",
    frame: []const u8 = "",
    content: []const u8 = "",
    created_at: ?[]const u8 = null,
};

pub const PathGrant = struct {
    root: []const u8,
    access: []const u8 = "read",
};

pub const Action = struct {
    kind: []const u8,
    session_id: []const u8,
    tool_name: ?[]const u8 = null,
    arguments: ?json.Json = null,
};

pub const Decision = struct {
    allowed: bool = false,
    reason: []const u8 = "",
};

pub const Event = struct {
    type: []const u8,
    session_id: []const u8,
    run_id: ?[]const u8 = null,
    data: ?json.Json = null,
};

pub fn usagePlus(left: Usage, right: Usage) Usage {
    return .{
        .input_tokens = left.input_tokens + right.input_tokens,
        .output_tokens = left.output_tokens + right.output_tokens,
        .cached_tokens = left.cached_tokens + right.cached_tokens,
    };
}

pub fn messageWire(allocator: std.mem.Allocator, message: Message) !json.Json {
    var object = std.json.ObjectMap.empty;
    try object.put(allocator, "role", .{ .string = message.role });
    if (message.content) |content| try object.put(allocator, "content", .{ .string = content });
    if (message.content_blocks.len > 0) {
        var blocks = std.json.Array.init(allocator);
        for (message.content_blocks) |block| {
            var item = std.json.ObjectMap.empty;
            try item.put(allocator, "type", .{ .string = block.type });
            if (block.text) |text| try item.put(allocator, "text", .{ .string = text });
            if (block.image_url) |image| try item.put(allocator, "image_url", .{ .string = image });
            if (block.data) |data| try item.put(allocator, "data", .{ .string = data });
            try blocks.append(.{ .object = item });
        }
        try object.put(allocator, "contentBlocks", .{ .array = blocks });
    }
    if (message.tool_calls.len > 0) {
        var calls = std.json.Array.init(allocator);
        for (message.tool_calls) |call| {
            var item = std.json.ObjectMap.empty;
            try item.put(allocator, "id", .{ .string = call.id });
            try item.put(allocator, "name", .{ .string = call.name });
            try item.put(allocator, "arguments", call.arguments);
            try calls.append(.{ .object = item });
        }
        try object.put(allocator, "toolCalls", .{ .array = calls });
    }
    if (message.tool_id) |tool_id| try object.put(allocator, "toolId", .{ .string = tool_id });
    return .{ .object = object };
}

pub fn eventWire(allocator: std.mem.Allocator, event: Event) !json.Json {
    var object = std.json.ObjectMap.empty;
    try object.put(allocator, "type", .{ .string = event.type });
    try object.put(allocator, "sessionId", .{ .string = event.session_id });
    if (event.run_id) |run_id| try object.put(allocator, "runId", .{ .string = run_id });
    if (event.data) |data| try object.put(allocator, "data", data);
    return .{ .object = object };
}
