const std = @import("std");
const agent = @import("agent.zig");
const json = @import("json.zig");
const models = @import("models.zig");

const Allocator = std.mem.Allocator;

pub const ProviderError = error{
    ProviderBaseUrlRequired,
    ProviderHttp,
    ProviderJson,
};

pub const TransportResult = struct {
    status: u16,
    body: []const u8,
};

pub const Transport = struct {
    ctx: *anyopaque,
    sendFn: *const fn (ctx: *anyopaque, allocator: Allocator, path: []const u8, payload: json.Json) anyerror!TransportResult,

    pub fn send(self: Transport, allocator: Allocator, path: []const u8, payload: json.Json) !TransportResult {
        return self.sendFn(self.ctx, allocator, path, payload);
    }
};

pub const Adapter = struct {
    allocator: Allocator,
    base_url: []const u8,
    model: []const u8,
    api_key: []const u8 = "",
    transport: ?Transport = null,

    pub fn init(allocator: Allocator, base_url: []const u8, model: []const u8) Adapter {
        return .{ .allocator = allocator, .base_url = base_url, .model = model };
    }

    pub fn payload(self: *const Adapter, request: models.Request) !json.Json {
        var root = std.json.ObjectMap.empty;
        try root.put(self.allocator, "model", .{ .string = self.model });
        var messages = std.json.Array.init(self.allocator);
        for (request.messages) |message| {
            try messages.append(try messagePayload(self.allocator, message));
        }
        try root.put(self.allocator, "messages", .{ .array = messages });
        if (request.tools.len > 0) {
            var tools = std.json.Array.init(self.allocator);
            for (request.tools) |tool| {
                try tools.append(try toolPayload(self.allocator, tool));
            }
            try root.put(self.allocator, "tools", .{ .array = tools });
        }
        if (request.tool_choice) |choice| {
            if (choice.len > 0) {
                try root.put(self.allocator, "tool_choice", .{ .string = choice });
            }
        }
        return .{ .object = root };
    }

    pub fn parseResponse(self: *const Adapter, data: json.Json) !models.Response {
        if (json.get(data, "error")) |provider_error| {
            if (provider_error == .object) return ProviderError.ProviderHttp;
        }
        const choices = json.array(data, "choices");
        if (choices.len == 0) return ProviderError.ProviderJson;
        const choice = choices[0];
        const message = json.get(choice, "message") orelse return ProviderError.ProviderJson;
        if (message != .object) return ProviderError.ProviderJson;
        var tool_calls = std.array_list.Managed(models.ToolCall).init(self.allocator);
        for (json.array(message, "tool_calls")) |call| {
            const function = json.get(call, "function") orelse continue;
            const raw_arguments = json.string(function, "arguments") orelse "";
            var arguments = json.Json{ .object = .empty };
            if (raw_arguments.len > 0) {
                arguments = json.parse(self.allocator, raw_arguments) catch return ProviderError.ProviderJson;
                if (arguments != .object) return ProviderError.ProviderJson;
            }
            try tool_calls.append(.{
                .id = json.string(call, "id") orelse "",
                .name = json.string(function, "name") orelse "",
                .arguments = arguments,
            });
        }
        const usage = json.get(data, "usage") orelse json.Json{ .null = {} };
        return .{
            .message = .{
                .role = models.ASSISTANT,
                .content = json.string(message, "content") orelse "",
                .tool_calls = try tool_calls.toOwnedSlice(),
            },
            .usage = .{
                .input_tokens = json.integer(usage, "prompt_tokens", 0),
                .output_tokens = json.integer(usage, "completion_tokens", 0),
            },
            .finish_reason = json.string(choice, "finish_reason"),
        };
    }

    pub fn generate(self: *Adapter, request: models.Request) !models.Response {
        if (self.base_url.len == 0) return ProviderError.ProviderBaseUrlRequired;
        const request_payload = try self.payload(request);
        const body = try json.stringify(self.allocator, request_payload);
        const result = if (self.transport) |transport|
            try transport.send(self.allocator, "/chat/completions", request_payload)
        else
            try self.post(body);
        if (result.status < 200 or result.status >= 300) return ProviderError.ProviderHttp;
        const data = json.parse(self.allocator, result.body) catch return ProviderError.ProviderJson;
        return self.parseResponse(data);
    }

    pub fn asModel(self: *Adapter) agent.Model {
        return .{ .ctx = self, .generateFn = generateModel };
    }

    fn generateModel(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *Adapter = @ptrCast(@alignCast(ctx));
        return self.generate(request);
    }

    fn post(self: *Adapter, body: []const u8) !TransportResult {
        const base = std.mem.trimEnd(u8, self.base_url, "/");
        const url = try std.fmt.allocPrint(self.allocator, "{s}/chat/completions", .{base});
        defer self.allocator.free(url);
        var output = std.Io.Writer.Allocating.init(self.allocator);
        defer output.deinit();
        var client = std.http.Client{
            .allocator = self.allocator,
            .io = std.Io.Threaded.global_single_threaded.io(),
        };
        defer client.deinit();
        var auth_buffer: [512]u8 = undefined;
        var header_buffer: [2]std.http.Header = undefined;
        header_buffer[0] = .{ .name = "content-type", .value = "application/json" };
        var headers: []const std.http.Header = header_buffer[0..1];
        if (self.api_key.len > 0) {
            const value = try std.fmt.bufPrint(&auth_buffer, "Bearer {s}", .{self.api_key});
            header_buffer[1] = .{ .name = "authorization", .value = value };
            headers = header_buffer[0..2];
        }
        const response = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .extra_headers = headers,
            .response_writer = &output.writer,
        });
        return .{
            .status = @intFromEnum(response.status),
            .body = try output.toOwnedSlice(),
        };
    }
};

fn messagePayload(allocator: Allocator, message: models.Message) !json.Json {
    var object = std.json.ObjectMap.empty;
    try object.put(allocator, "role", .{ .string = message.role });
    var content: []const u8 = message.content orelse "";
    if (content.len == 0 and message.content_blocks.len > 0) {
        var joined = std.array_list.Managed(u8).init(allocator);
        for (message.content_blocks) |block| {
            if (std.mem.eql(u8, block.type, "text")) {
                if (block.text) |text| try joined.appendSlice(text);
            }
        }
        content = try joined.toOwnedSlice();
    }
    try object.put(allocator, "content", .{ .string = content });
    if (std.mem.eql(u8, message.role, models.ASSISTANT) and message.tool_calls.len > 0) {
        var calls = std.json.Array.init(allocator);
        for (message.tool_calls) |call| {
            var function_object = std.json.ObjectMap.empty;
            try function_object.put(allocator, "name", .{ .string = call.name });
            const arguments = try json.stringify(allocator, call.arguments);
            try function_object.put(allocator, "arguments", .{ .string = arguments });
            var call_object = std.json.ObjectMap.empty;
            try call_object.put(allocator, "id", .{ .string = call.id });
            try call_object.put(allocator, "type", .{ .string = "function" });
            try call_object.put(allocator, "function", .{ .object = function_object });
            try calls.append(.{ .object = call_object });
        }
        try object.put(allocator, "tool_calls", .{ .array = calls });
    }
    if (std.mem.eql(u8, message.role, models.TOOL)) {
        if (message.tool_id) |tool_id| {
            if (tool_id.len > 0) {
                try object.put(allocator, "tool_call_id", .{ .string = tool_id });
            }
        }
    }
    return .{ .object = object };
}

fn toolPayload(allocator: Allocator, tool: models.ToolSpec) !json.Json {
    var function_object = std.json.ObjectMap.empty;
    try function_object.put(allocator, "name", .{ .string = tool.name });
    try function_object.put(allocator, "description", .{ .string = tool.description });
    if (tool.parameters) |parameters| {
        try function_object.put(allocator, "parameters", parameters);
    } else {
        try function_object.put(allocator, "parameters", json.Json{ .object = .empty });
    }
    var object = std.json.ObjectMap.empty;
    try object.put(allocator, "type", .{ .string = "function" });
    try object.put(allocator, "function", .{ .object = function_object });
    return .{ .object = object };
}

pub fn providerCode(error_value: anyerror) []const u8 {
    return switch (error_value) {
        ProviderError.ProviderHttp, ProviderError.ProviderBaseUrlRequired => "PROVIDER_HTTP",
        ProviderError.ProviderJson => "PROVIDER_JSON",
        else => @errorName(error_value),
    };
}
