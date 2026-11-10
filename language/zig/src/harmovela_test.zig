const std = @import("std");
const harmovela = @import("harmovela.zig");
const json = @import("json.zig");
const models = @import("models.zig");

const Fake = struct {
    status: u16 = 201,
    body: []const u8 = "",
    calls: usize = 0,
    method: []const u8 = "",
    url: []const u8 = "",
    content_type: []const u8 = "",
    request_body: []const u8 = "",

    fn send(ctx: *anyopaque, allocator: std.mem.Allocator, request: harmovela.HttpRequest) anyerror!harmovela.TransportResult {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        self.method = try allocator.dupe(u8, request.method);
        self.url = try allocator.dupe(u8, request.url);
        self.content_type = try allocator.dupe(u8, request.content_type);
        self.request_body = try allocator.dupe(u8, request.body);
        return .{ .status = self.status, .body = self.body };
    }

    fn transport(self: *Fake) harmovela.Transport {
        return .{ .ctx = self, .sendFn = send };
    }
};

fn fixedClock() harmovela.TimeParts {
    return .{ .seconds = 1_794_294_000, .nanos = 0 };
}

fn makeEvent(allocator: std.mem.Allocator) !models.Event {
    var data = std.json.ObjectMap.empty;
    try data.put(allocator, "name", .{ .string = "echo" });
    return .{
        .type = "tool.call",
        .session_id = "s1",
        .run_id = "run-123",
        .data = .{ .object = data },
    };
}

test "harmovela posts envelope and merges payload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{};
    var sink = harmovela.Sink.init(allocator, "http://harmovela.test/aep/api/");
    sink.transport = fake.transport();
    sink.clock = fixedClock;
    try sink.emit(try makeEvent(allocator));
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqualStrings("POST", fake.method);
    try std.testing.expectEqualStrings("http://harmovela.test/aep/api/events", fake.url);
    try std.testing.expectEqualStrings("application/json", fake.content_type);
    const envelope = try json.parse(allocator, fake.request_body);
    try std.testing.expectEqualStrings("0.2", json.string(envelope, "spec_version").?);
    try std.testing.expectEqualStrings("run-123-1794294000000000000", json.string(envelope, "id").?);
    try std.testing.expectEqualStrings("tool.call", json.string(envelope, "type").?);
    try std.testing.expectEqualStrings("praxo-core", json.string(envelope, "source").?);
    try std.testing.expectEqualStrings("2026-11-10T07:00:00.000000000Z", json.string(envelope, "created_at").?);
    const payload = json.get(envelope, "payload").?;
    try std.testing.expectEqualStrings("echo", json.string(payload, "name").?);
    try std.testing.expectEqualStrings("s1", json.string(payload, "session_id").?);
    try std.testing.expectEqualStrings("run-123", json.string(payload, "run_id").?);
}

test "harmovela merge keeps event data and overrides session" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var data = std.json.ObjectMap.empty;
    try data.put(allocator, "name", .{ .string = "echo" });
    try data.put(allocator, "session_id", .{ .string = "event-side" });
    try data.put(allocator, "run_id", .{ .string = "old" });
    var fake = Fake{};
    var sink = harmovela.Sink.init(allocator, "http://harmovela.test");
    sink.source = "custom";
    sink.spec_version = "0.3";
    sink.transport = fake.transport();
    sink.clock = fixedClock;
    try sink.emit(.{
        .type = "tool.call",
        .session_id = "s1",
        .run_id = null,
        .data = .{ .object = data },
    });
    const envelope = try json.parse(allocator, fake.request_body);
    try std.testing.expectEqualStrings("custom", json.string(envelope, "source").?);
    try std.testing.expectEqualStrings("0.3", json.string(envelope, "spec_version").?);
    try std.testing.expect(std.mem.startsWith(u8, json.string(envelope, "id").?, "s1-"));
    const payload = json.get(envelope, "payload").?;
    try std.testing.expectEqualStrings("s1", json.string(payload, "session_id").?);
    try std.testing.expectEqualStrings("old", json.string(payload, "run_id").?);
}

test "harmovela accepts every 2xx status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]u16{ 200, 201, 204, 299 }) |status| {
        var fake = Fake{ .status = status };
        var sink = harmovela.Sink.init(allocator, "http://harmovela.test");
        sink.transport = fake.transport();
        sink.clock = fixedClock;
        try sink.emit(try makeEvent(allocator));
        try std.testing.expectEqual(@as(usize, 1), fake.calls);
    }
}

test "harmovela reports status and bounded body on non-2xx" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var body = std.array_list.Managed(u8).init(allocator);
    for (0..100) |_| try body.appendSlice("service down ");
    const repeated = try body.toOwnedSlice();
    var fake = Fake{ .status = 503, .body = repeated };
    var sink = harmovela.Sink.init(allocator, "http://harmovela.test");
    sink.transport = fake.transport();
    sink.clock = fixedClock;
    try std.testing.expectError(harmovela.SinkError.HarmovelaHttp, sink.emit(try makeEvent(allocator)));
    const message = sink.last_error.?;
    try std.testing.expect(std.mem.indexOf(u8, message, "503") != null);
    try std.testing.expect(std.mem.indexOf(u8, message, "service down") != null);
    try std.testing.expect(message.len <= 600);
}

test "harmovela requires a base URL" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var sink = harmovela.Sink.init(arena.allocator(), "");
    try std.testing.expectError(harmovela.SinkError.HarmovelaBaseUrlRequired, sink.emit(try makeEvent(arena.allocator())));
}
