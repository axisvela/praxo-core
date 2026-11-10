const std = @import("std");
const json = @import("json.zig");
const models = @import("models.zig");
const openai = @import("openaicompat.zig");

const Fake = struct {
    status: u16 = 200,
    body: []const u8 = "",
    captured_path: []const u8 = "",
    captured_payload: ?json.Json = null,
    calls: usize = 0,

    fn send(ctx: *anyopaque, allocator: std.mem.Allocator, path: []const u8, payload: json.Json) anyerror!openai.TransportResult {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        self.captured_path = try allocator.dupe(u8, path);
        self.captured_payload = payload;
        return .{ .status = self.status, .body = self.body };
    }

    fn transport(self: *Fake) openai.Transport {
        return .{ .ctx = self, .sendFn = send };
    }
};

test "openai compatible generate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .body =
        "{\"choices\":[{\"message\":{\"content\":\"hello\",\"tool_calls\":[" ++
        "{\"id\":\"c1\",\"type\":\"function\",\"function\":" ++
        "{\"name\":\"echo\",\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]}," ++
        "\"finish_reason\":\"tool_calls\"}]," ++
        "\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2}}" };
    var adapter = openai.Adapter.init(allocator, "http://example.test/v1", "test-model");
    adapter.transport = fake.transport();
    const request = models.Request{
        .messages = &.{.{ .role = models.USER, .content = "hello" }},
        .tools = &.{.{ .name = "echo", .description = "Echo" }},
        .tool_choice = "auto",
    };
    const response = try adapter.generate(request);
    try std.testing.expectEqualStrings("/chat/completions", fake.captured_path);
    const payload = fake.captured_payload.?;
    try std.testing.expectEqualStrings("test-model", json.string(payload, "model").?);
    const messages = json.array(payload, "messages");
    try std.testing.expectEqual(@as(usize, 1), messages.len);
    try std.testing.expectEqualStrings("hello", json.string(messages[0], "content").?);
    const tools = json.array(payload, "tools");
    try std.testing.expectEqual(@as(usize, 1), tools.len);
    const function_object = json.object(tools[0], "function").?;
    try std.testing.expectEqualStrings("echo", function_object.get("name").?.string);
    try std.testing.expectEqualStrings("auto", json.string(payload, "tool_choice").?);
    try std.testing.expectEqualStrings("hello", response.message.content.?);
    try std.testing.expectEqual(@as(usize, 1), response.message.tool_calls.len);
    try std.testing.expectEqualStrings("echo", response.message.tool_calls[0].name);
    try std.testing.expectEqualStrings("hi", json.string(response.message.tool_calls[0].arguments, "text").?);
    try std.testing.expectEqual(@as(i64, 3), response.usage.input_tokens);
    try std.testing.expectEqual(@as(i64, 2), response.usage.output_tokens);
    try std.testing.expectEqualStrings("tool_calls", response.finish_reason.?);
}

test "openai compatible request mapping" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .body = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}" };
    var adapter = openai.Adapter.init(allocator, "http://example.test/v1", "test-model");
    adapter.transport = fake.transport();
    const arguments = try json.parse(allocator, "{\"text\":\"bye\"}");
    const calls = [_]models.ToolCall{.{ .id = "c1", .name = "echo", .arguments = arguments }};
    const messages = [_]models.Message{
        .{ .role = models.ASSISTANT, .content = "", .tool_calls = &calls },
        .{ .role = models.TOOL, .content = "{\"ok\":true}", .tool_id = "c1" },
    };
    _ = try adapter.generate(.{ .messages = &messages });
    const payload = fake.captured_payload.?;
    const encoded = json.array(payload, "messages");
    const encoded_calls = json.array(encoded[0], "tool_calls");
    try std.testing.expectEqual(@as(usize, 1), encoded_calls.len);
    try std.testing.expectEqualStrings("c1", json.string(encoded_calls[0], "id").?);
    const function_object = json.object(encoded_calls[0], "function").?;
    const raw_arguments = function_object.get("arguments").?.string;
    const parsed = try json.parse(allocator, raw_arguments);
    try std.testing.expectEqualStrings("bye", json.string(parsed, "text").?);
    try std.testing.expectEqualStrings("c1", json.string(encoded[1], "tool_call_id").?);
}

test "openai compatible http errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .status = 500, .body = "server error" };
    var adapter = openai.Adapter.init(allocator, "http://example.test/v1", "test-model");
    adapter.transport = fake.transport();
    try std.testing.expectError(openai.ProviderError.ProviderHttp,
        adapter.generate(.{ .messages = &.{.{ .role = models.USER, .content = "hi" }} }));

    fake.status = 200;
    fake.body = "{\"choices\":[{\"message\":{\"content\":\"\",\"tool_calls\":[" ++
        "{\"id\":\"c1\",\"function\":{\"name\":\"echo\",\"arguments\":\"not json\"}}]}}]}";
    try std.testing.expectError(openai.ProviderError.ProviderJson,
        adapter.generate(.{ .messages = &.{.{ .role = models.USER, .content = "hi" }} }));

    fake.calls = 0;
    adapter.base_url = "";
    try std.testing.expectError(openai.ProviderError.ProviderBaseUrlRequired,
        adapter.generate(.{ .messages = &.{.{ .role = models.USER, .content = "hi" }} }));
    try std.testing.expectEqual(@as(usize, 0), fake.calls);

    try std.testing.expectEqualStrings("PROVIDER_HTTP", openai.providerCode(openai.ProviderError.ProviderHttp));
    try std.testing.expectEqualStrings("PROVIDER_JSON", openai.providerCode(openai.ProviderError.ProviderJson));
}

test "openai compatible model callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .body = "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}" };
    var adapter = openai.Adapter.init(allocator, "http://example.test/v1", "test-model");
    adapter.transport = fake.transport();
    const model = adapter.asModel();
    const response = try model.generate(.{
        .messages = &.{.{ .role = models.USER, .content = "hi" }},
    });
    try std.testing.expectEqualStrings("ok", response.message.content.?);
}
