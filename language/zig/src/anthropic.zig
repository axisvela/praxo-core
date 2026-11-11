const std = @import("std");
const agent = @import("agent.zig");
const json = @import("json.zig");
const models = @import("models.zig");
const compat = @import("openaicompat.zig");

const Allocator = std.mem.Allocator;

pub const Adapter = struct {
    allocator: Allocator,
    base_url: []const u8,
    model: []const u8,
    api_key: []const u8 = "",
    version: []const u8 = "2023-06-01",
    max_tokens: i64 = 1024,
    transport: ?compat.Transport = null,

    pub fn init(allocator: Allocator, base_url: []const u8, model: []const u8) Adapter {
        return .{ .allocator = allocator, .base_url = base_url, .model = model };
    }

    pub fn payload(self: *const Adapter, request: models.Request) !json.Json {
        var system = std.array_list.Managed(u8).init(self.allocator);
        var messages = std.json.Array.init(self.allocator);
        var pending = std.json.Array.init(self.allocator);
        for (request.messages) |message| {
            if (std.mem.eql(u8, message.role, models.SYSTEM)) {
                if (message.content) |text| {
                    if (text.len > 0) {
                        if (system.items.len > 0) try system.appendSlice("\n\n");
                        try system.appendSlice(text);
                    }
                }
                continue;
            }
            if (std.mem.eql(u8, message.role, models.TOOL)) {
                var item = std.json.ObjectMap.empty;
                try item.put(self.allocator, "type", .{ .string = "tool_result" });
                try item.put(self.allocator, "tool_use_id", .{ .string = message.tool_id orelse "" });
                try item.put(self.allocator, "content", .{ .string = message.content orelse "" });
                try pending.append(.{ .object = item });
                continue;
            }
            if (pending.items.len > 0) {
                var group = std.json.ObjectMap.empty;
                try group.put(self.allocator, "role", .{ .string = "user" });
                try group.put(self.allocator, "content", .{ .array = pending });
                try messages.append(.{ .object = group });
                pending = std.json.Array.init(self.allocator);
            }
            const content = try messageContent(self.allocator, message);
            if (content.array.items.len > 0) {
                var item = std.json.ObjectMap.empty;
                try item.put(self.allocator, "role", .{ .string = message.role });
                try item.put(self.allocator, "content", content);
                try messages.append(.{ .object = item });
            }
        }
        if (pending.items.len > 0) {
            var group = std.json.ObjectMap.empty;
            try group.put(self.allocator, "role", .{ .string = "user" });
            try group.put(self.allocator, "content", .{ .array = pending });
            try messages.append(.{ .object = group });
        }
        var root = std.json.ObjectMap.empty;
        try root.put(self.allocator, "model", .{ .string = self.model });
        try root.put(self.allocator, "max_tokens", .{ .integer = self.max_tokens });
        try root.put(self.allocator, "messages", .{ .array = messages });
        if (system.items.len > 0) {
            try root.put(self.allocator, "system", .{ .string = try system.toOwnedSlice() });
        }
        if (request.tools.len > 0) {
            var tools = std.json.Array.init(self.allocator);
            for (request.tools) |tool| {
                var item = std.json.ObjectMap.empty;
                try item.put(self.allocator, "name", .{ .string = tool.name });
                try item.put(self.allocator, "description", .{ .string = tool.description });
                try item.put(self.allocator, "input_schema", tool.parameters orelse .{ .object = .empty });
                try tools.append(.{ .object = item });
            }
            try root.put(self.allocator, "tools", .{ .array = tools });
            if (request.tool_choice) |choice| {
                var value = std.json.ObjectMap.empty;
                const kind: ?[]const u8 = if (std.mem.eql(u8, choice, "auto")) "auto" else if (std.mem.eql(u8, choice, "required")) "any" else if (std.mem.eql(u8, choice, "none")) "none" else null;
                if (kind) |kind_value| {
                    try value.put(self.allocator, "type", .{ .string = kind_value });
                    try root.put(self.allocator, "tool_choice", .{ .object = value });
                }
            }
        }
        if (request.temperature != 0) {
            try root.put(self.allocator, "temperature", .{ .float = request.temperature });
        }
        return .{ .object = root };
    }

    pub fn parseResponse(self: *const Adapter, data: json.Json) !models.Response {
        if (json.get(data, "error") != null) return compat.ProviderError.ProviderHttp;
        var text = std.array_list.Managed(u8).init(self.allocator);
        var calls = std.array_list.Managed(models.ToolCall).init(self.allocator);
        for (json.array(data, "content")) |block| {
            const kind = json.string(block, "type") orelse "";
            if (std.mem.eql(u8, kind, "text")) {
                if (json.string(block, "text")) |value| try text.appendSlice(value);
            } else if (std.mem.eql(u8, kind, "tool_use")) {
                var arguments = json.Json{ .object = .empty };
                if (json.get(block, "input")) |input| {
                    if (input == .object) arguments = input;
                }
                try calls.append(.{
                    .id = json.string(block, "id") orelse "",
                    .name = json.string(block, "name") orelse "",
                    .arguments = arguments,
                });
            }
        }
        const usage = json.get(data, "usage") orelse json.Json{ .null = {} };
        return .{
            .message = .{
                .role = models.ASSISTANT,
                .content = try text.toOwnedSlice(),
                .tool_calls = try calls.toOwnedSlice(),
            },
            .usage = .{
                .input_tokens = json.integer(usage, "input_tokens", 0),
                .output_tokens = json.integer(usage, "output_tokens", 0),
                .cached_tokens = json.integer(usage, "cache_read_input_tokens", 0),
            },
            .finish_reason = json.string(data, "stop_reason"),
        };
    }

    pub fn generate(self: *Adapter, request: models.Request) !models.Response {
        if (self.base_url.len == 0 or self.api_key.len == 0 or self.model.len == 0) return compat.ProviderError.ProviderBaseUrlRequired;
        const request_payload = try self.payload(request);
        const result = if (self.transport) |transport|
            try transport.send(self.allocator, "/v1/messages", request_payload)
        else
            try self.post(request_payload);
        if (result.status < 200 or result.status >= 300) return compat.ProviderError.ProviderHttp;
        const data = json.parse(self.allocator, result.body) catch return compat.ProviderError.ProviderJson;
        return self.parseResponse(data);
    }

    pub fn asModel(self: *Adapter) agent.Model {
        return .{ .ctx = self, .generateFn = generateModel };
    }

    fn generateModel(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *Adapter = @ptrCast(@alignCast(ctx));
        return self.generate(request);
    }

    fn post(self: *Adapter, request_payload: json.Json) !compat.TransportResult {
        const base = std.mem.trimEnd(u8, self.base_url, "/");
        const url = try std.fmt.allocPrint(self.allocator, "{s}/v1/messages", .{base});
        defer self.allocator.free(url);
        const body = try json.stringify(self.allocator, request_payload);
        defer self.allocator.free(body);
        var output = std.Io.Writer.Allocating.init(self.allocator);
        defer output.deinit();
        var client = std.http.Client{
            .allocator = self.allocator,
            .io = std.Io.Threaded.global_single_threaded.io(),
        };
        defer client.deinit();
        var key_buffer: [512]u8 = undefined;
        const key_header = try std.fmt.bufPrint(&key_buffer, "{s}", .{self.api_key});
        const headers = [_]std.http.Header{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "x-api-key", .value = key_header },
            .{ .name = "anthropic-version", .value = self.version },
        };
        const response = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .extra_headers = &headers,
            .response_writer = &output.writer,
        });
        return .{ .status = @intFromEnum(response.status), .body = try output.toOwnedSlice() };
    }
};

fn messageContent(allocator: Allocator, message: models.Message) !json.Json {
    var content = std.json.Array.init(allocator);
    if (message.content) |text| {
        if (text.len > 0) {
            var item = std.json.ObjectMap.empty;
            try item.put(allocator, "type", .{ .string = "text" });
            try item.put(allocator, "text", .{ .string = text });
            try content.append(.{ .object = item });
        }
    }
    for (message.content_blocks) |block| {
        if (std.mem.eql(u8, block.type, "text")) {
            if (block.text) |text| {
                if (text.len > 0) {
                    var item = std.json.ObjectMap.empty;
                    try item.put(allocator, "type", .{ .string = "text" });
                    try item.put(allocator, "text", .{ .string = text });
                    try content.append(.{ .object = item });
                }
            }
        }
    }
    for (message.tool_calls) |call| {
        var item = std.json.ObjectMap.empty;
        try item.put(allocator, "type", .{ .string = "tool_use" });
        try item.put(allocator, "id", .{ .string = call.id });
        try item.put(allocator, "name", .{ .string = call.name });
        try item.put(allocator, "input", call.arguments);
        try content.append(.{ .object = item });
    }
    return .{ .array = content };
}

test "anthropic maps request and response" {
    const allocator = std.heap.page_allocator;
    var captured_path: []const u8 = "";
    var captured_payload: json.Json = .{ .null = {} };
    const Context = struct {
        path: *[]const u8,
        payload: *json.Json,
        fn send(ctx: *anyopaque, allocator_value: Allocator, path: []const u8, payload: json.Json) anyerror!compat.TransportResult {
            _ = allocator_value;
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.path.* = path;
            self.payload.* = payload;
            const body = try json.stringify(std.heap.page_allocator, payload);
            _ = body;
            return .{ .status = 200, .body = "{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}],\"stop_reason\":\"end_turn\",\"usage\":{\"input_tokens\":3,\"output_tokens\":4,\"cache_read_input_tokens\":2}}" };
        }
    };
    var context = Context{ .path = &captured_path, .payload = &captured_payload };
    var adapter = Adapter.init(allocator, "https://example.test", "claude-test");
    adapter.api_key = "ak";
    adapter.transport = .{ .ctx = &context, .sendFn = Context.send };
    const request = models.Request{
        .messages = &.{
            .{ .role = models.SYSTEM, .content = "be brief" },
            .{ .role = models.USER, .content = "hi" },
        },
        .tools = &.{.{ .name = "echo", .description = "Echo" }},
        .tool_choice = "auto",
    };
    const response = try adapter.generate(request);
    try std.testing.expectEqualStrings("/v1/messages", captured_path);
    try std.testing.expectEqualStrings("hello", response.message.content.?);
    try std.testing.expectEqual(2, response.usage.cached_tokens);
    try std.testing.expectEqualStrings("tool-1", response.message.tool_calls[0].id);
    try std.testing.expectEqualStrings("hi", response.message.tool_calls[0].arguments.object.get("text").?.string);
}
