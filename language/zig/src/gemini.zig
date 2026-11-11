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
    max_output_tokens: i64 = 0,
    transport: ?compat.Transport = null,

    pub fn init(allocator: Allocator, base_url: []const u8, model: []const u8) Adapter {
        return .{ .allocator = allocator, .base_url = base_url, .model = model };
    }

    pub fn payload(self: *const Adapter, request: models.Request) !json.Json {
        var system = std.json.Array.init(self.allocator);
        var contents = std.json.Array.init(self.allocator);
        var pending = std.json.Array.init(self.allocator);
        var names = std.StringHashMap([]const u8).init(self.allocator);
        for (request.messages) |message| {
            if (std.mem.eql(u8, message.role, models.SYSTEM)) {
                if (message.content) |text| {
                    if (text.len > 0) {
                        var part = std.json.ObjectMap.empty;
                        try part.put(self.allocator, "text", .{ .string = text });
                        try system.append(.{ .object = part });
                    }
                }
                continue;
            }
            if (std.mem.eql(u8, message.role, models.TOOL)) {
                const id = message.tool_id orelse "";
                const name = names.get(id) orelse if (id.len > 0) id else "tool";
                var response = std.json.ObjectMap.empty;
                try response.put(self.allocator, "result", .{ .string = message.content orelse "" });
                var function = std.json.ObjectMap.empty;
                try function.put(self.allocator, "name", .{ .string = name });
                try function.put(self.allocator, "response", .{ .object = response });
                var part = std.json.ObjectMap.empty;
                try part.put(self.allocator, "functionResponse", .{ .object = function });
                try pending.append(.{ .object = part });
                continue;
            }
            if (pending.items.len > 0) {
                var group = std.json.ObjectMap.empty;
                try group.put(self.allocator, "role", .{ .string = "user" });
                try group.put(self.allocator, "parts", .{ .array = pending });
                try contents.append(.{ .object = group });
                pending = std.json.Array.init(self.allocator);
            }
            const parts = try messageParts(self.allocator, message);
            if (parts.array.items.len > 0) {
                var item = std.json.ObjectMap.empty;
                try item.put(self.allocator, "role", .{ .string = if (std.mem.eql(u8, message.role, models.ASSISTANT)) "model" else "user" });
                try item.put(self.allocator, "parts", parts);
                try contents.append(.{ .object = item });
            }
            for (message.tool_calls) |call| {
                if (call.id.len > 0 and call.name.len > 0) {
                    try names.put(call.id, call.name);
                }
            }
        }
        if (pending.items.len > 0) {
            var group = std.json.ObjectMap.empty;
            try group.put(self.allocator, "role", .{ .string = "user" });
            try group.put(self.allocator, "parts", .{ .array = pending });
            try contents.append(.{ .object = group });
        }
        var root = std.json.ObjectMap.empty;
        try root.put(self.allocator, "contents", .{ .array = contents });
        if (system.items.len > 0) {
            var instruction = std.json.ObjectMap.empty;
            try instruction.put(self.allocator, "parts", .{ .array = system });
            try root.put(self.allocator, "system_instruction", .{ .object = instruction });
        }
        if (request.tools.len > 0) {
            var declarations = std.json.Array.init(self.allocator);
            for (request.tools) |tool| {
                var item = std.json.ObjectMap.empty;
                try item.put(self.allocator, "name", .{ .string = tool.name });
                try item.put(self.allocator, "description", .{ .string = tool.description });
                try item.put(self.allocator, "parameters", tool.parameters orelse .{ .object = .empty });
                try declarations.append(.{ .object = item });
            }
            var group = std.json.ObjectMap.empty;
            try group.put(self.allocator, "functionDeclarations", .{ .array = declarations });
            var tools = std.json.Array.init(self.allocator);
            try tools.append(.{ .object = group });
            try root.put(self.allocator, "tools", .{ .array = tools });
            const mode = if (request.tool_choice) |choice|
                if (std.mem.eql(u8, choice, "required")) "ANY" else if (std.mem.eql(u8, choice, "none")) "NONE" else "AUTO"
            else
                "AUTO";
            var config = std.json.ObjectMap.empty;
            var calling = std.json.ObjectMap.empty;
            try calling.put(self.allocator, "mode", .{ .string = mode });
            try config.put(self.allocator, "functionCallingConfig", .{ .object = calling });
            try root.put(self.allocator, "toolConfig", .{ .object = config });
        }
        if (self.max_output_tokens > 0) {
            var generation = std.json.ObjectMap.empty;
            try generation.put(self.allocator, "maxOutputTokens", .{ .integer = self.max_output_tokens });
            try root.put(self.allocator, "generationConfig", .{ .object = generation });
        }
        return .{ .object = root };
    }

    pub fn parseResponse(self: *const Adapter, data: json.Json) !models.Response {
        if (json.get(data, "error") != null) return compat.ProviderError.ProviderHttp;
        const candidates = json.array(data, "candidates");
        if (candidates.len == 0) return compat.ProviderError.ProviderHttp;
        const candidate = candidates[0];
        const content = json.get(candidate, "content") orelse json.Json{ .null = {} };
        var text = std.array_list.Managed(u8).init(self.allocator);
        var calls = std.array_list.Managed(models.ToolCall).init(self.allocator);
        var call_index: usize = 0;
        for (json.array(content, "parts")) |part| {
            if (json.string(part, "text")) |value| try text.appendSlice(value);
            if (json.get(part, "functionCall")) |call| {
                if (call != .object) continue;
                var arguments = json.Json{ .object = .empty };
                if (json.get(call, "args")) |args| {
                    if (args == .object) arguments = args;
                }
                call_index += 1;
                try calls.append(.{
                    .id = try std.fmt.allocPrint(self.allocator, "call-{d}", .{call_index}),
                    .name = json.string(call, "name") orelse "",
                    .arguments = arguments,
                });
            }
        }
        const usage = json.get(data, "usageMetadata") orelse json.Json{ .null = {} };
        return .{
            .message = .{
                .role = models.ASSISTANT,
                .content = try text.toOwnedSlice(),
                .tool_calls = try calls.toOwnedSlice(),
            },
            .usage = .{
                .input_tokens = json.integer(usage, "promptTokenCount", 0),
                .output_tokens = json.integer(usage, "candidatesTokenCount", 0),
                .cached_tokens = json.integer(usage, "cachedContentTokenCount", 0),
            },
            .finish_reason = json.string(candidate, "finishReason"),
        };
    }

    pub fn generate(self: *Adapter, request: models.Request) !models.Response {
        if (self.base_url.len == 0 or self.api_key.len == 0 or self.model.len == 0) return compat.ProviderError.ProviderBaseUrlRequired;
        const request_payload = try self.payload(request);
        const path = try std.fmt.allocPrint(self.allocator, "/v1beta/models/{s}:generateContent", .{self.model});
        const result = if (self.transport) |transport|
            try transport.send(self.allocator, path, request_payload)
        else
            try self.post(path, request_payload);
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

    fn post(self: *Adapter, path: []const u8, request_payload: json.Json) !compat.TransportResult {
        const base = std.mem.trimEnd(u8, self.base_url, "/");
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base, path });
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
        const headers = [_]std.http.Header{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "x-goog-api-key", .value = self.api_key },
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

fn messageParts(allocator: Allocator, message: models.Message) !json.Json {
    var parts = std.json.Array.init(allocator);
    if (message.content) |text| {
        if (text.len > 0) {
            var part = std.json.ObjectMap.empty;
            try part.put(allocator, "text", .{ .string = text });
            try parts.append(.{ .object = part });
        }
    }
    for (message.content_blocks) |block| {
        if (std.mem.eql(u8, block.type, "text")) {
            if (block.text) |text| {
                if (text.len > 0) {
                    var part = std.json.ObjectMap.empty;
                    try part.put(allocator, "text", .{ .string = text });
                    try parts.append(.{ .object = part });
                }
            }
        }
    }
    for (message.tool_calls) |call| {
        var function = std.json.ObjectMap.empty;
        try function.put(allocator, "name", .{ .string = call.name });
        try function.put(allocator, "args", call.arguments);
        var part = std.json.ObjectMap.empty;
        try part.put(allocator, "functionCall", .{ .object = function });
        try parts.append(.{ .object = part });
    }
    return .{ .array = parts };
}

test "gemini maps request and response" {
    const allocator = std.heap.page_allocator;
    var captured_path: []const u8 = "";
    const Context = struct {
        path: *[]const u8,
        fn send(ctx: *anyopaque, allocator_value: Allocator, path: []const u8, payload: json.Json) anyerror!compat.TransportResult {
            _ = allocator_value;
            _ = payload;
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.path.* = path;
            return .{ .status = 200, .body = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":4}}" };
        }
    };
    var context = Context{ .path = &captured_path };
    var adapter = Adapter.init(allocator, "https://example.test", "gemini-test");
    adapter.api_key = "gk";
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
    try std.testing.expect(std.mem.indexOf(u8, captured_path, ":generateContent") != null);
    try std.testing.expectEqualStrings("hello", response.message.content.?);
    try std.testing.expectEqual(@as(i64, 3), response.usage.input_tokens);
    try std.testing.expectEqualStrings("echo", response.message.tool_calls[0].name);
}
