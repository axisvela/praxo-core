const std = @import("std");
const json = @import("json.zig");
const models = @import("models.zig");
const otel = @import("otel.zig");

const Fake = struct {
    status: u16 = 200,
    body: []const u8 = "",
    calls: usize = 0,
    method: []const u8 = "",
    url: []const u8 = "",
    content_type: []const u8 = "",
    request_body: []const u8 = "",

    fn send(ctx: *anyopaque, allocator: std.mem.Allocator, request: otel.HttpRequest) anyerror!otel.TransportResult {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        self.method = try allocator.dupe(u8, request.method);
        self.url = try allocator.dupe(u8, request.url);
        self.content_type = try allocator.dupe(u8, request.content_type);
        self.request_body = try allocator.dupe(u8, request.body);
        return .{ .status = self.status, .body = self.body };
    }

    fn transport(self: *Fake) otel.Transport {
        return .{ .ctx = self, .sendFn = send };
    }
};

fn fixedClock() otel.TimeParts {
    return .{ .seconds = 1_794_294_000, .nanos = 0 };
}

fn makeEvent(allocator: std.mem.Allocator) !models.Event {
    var data = std.json.ObjectMap.empty;
    try data.put(allocator, "name", .{ .string = "echo" });
    try data.put(allocator, "secret", .{ .string = "hidden" });
    return .{
        .type = "tool.call",
        .session_id = "s1",
        .run_id = "run-123",
        .data = .{ .object = data },
    };
}

test "otel posts an allowlisted OTLP span over the transport seam" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{};
    var sink = otel.Sink.init(allocator, "https://otel.test/v1/traces");
    sink.allowed_data_keys = &.{"name"};
    sink.transport = fake.transport();
    sink.clock = fixedClock;
    try sink.emit(try makeEvent(allocator));

    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqualStrings("POST", fake.method);
    try std.testing.expectEqualStrings("https://otel.test/v1/traces", fake.url);
    try std.testing.expectEqualStrings("application/json", fake.content_type);

    const envelope = try json.parse(allocator, fake.request_body);
    const resource_spans = json.array(envelope, "resourceSpans");
    try std.testing.expectEqual(@as(usize, 1), resource_spans.len);
    const resource_span = resource_spans[0];
    const scope_spans = json.array(resource_span, "scopeSpans");
    try std.testing.expectEqual(@as(usize, 1), scope_spans.len);
    const spans = json.array(scope_spans[0], "spans");
    try std.testing.expectEqual(@as(usize, 1), spans.len);
    const span = spans[0];
    try std.testing.expectEqualStrings("praxo.tool.call", json.string(span, "name").?);
    try std.testing.expectEqual(@as(usize, 32), json.string(span, "traceId").?.len);
    try std.testing.expectEqual(@as(usize, 16), json.string(span, "spanId").?.len);
    try std.testing.expectEqualStrings("1794294000000000000", json.string(span, "startTimeUnixNano").?);
    try std.testing.expectEqualStrings("1794294000000000000", json.string(span, "endTimeUnixNano").?);

    var saw_name = false;
    var saw_secret = false;
    for (json.array(span, "attributes")) |item| {
        const key = json.string(item, "key") orelse continue;
        if (std.mem.eql(u8, key, "praxo.event.data.name")) saw_name = true;
        if (std.mem.eql(u8, key, "praxo.event.data.secret")) saw_secret = true;
    }
    try std.testing.expect(saw_name);
    try std.testing.expect(!saw_secret);

    const first_body = fake.request_body;
    try sink.emit(try makeEvent(allocator));
    try std.testing.expectEqualStrings(first_body, fake.request_body);
}

test "otel requires an endpoint" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var sink = otel.Sink.init(allocator, "   ");
    try std.testing.expectError(
        otel.OtelError.OtelEndpointRequired,
        sink.emit(try makeEvent(allocator)),
    );
    try std.testing.expectEqualStrings(
        "OTEL_URL",
        otel.errorCode(otel.OtelError.OtelEndpointRequired),
    );
}

test "otel reports status and bounded body on non-2xx" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var long_body = try allocator.alloc(u8, 600);
    @memset(long_body, 'x');
    var fake = Fake{ .status = 503, .body = long_body };
    var sink = otel.Sink.init(allocator, "https://otel.test/v1/traces");
    sink.transport = fake.transport();
    sink.clock = fixedClock;
    try std.testing.expectError(
        otel.OtelError.OtelHttp,
        sink.emit(try makeEvent(allocator)),
    );
    const message = sink.last_error.?;
    try std.testing.expect(std.mem.indexOf(u8, message, "503") != null);
    try std.testing.expect(message.len < 600);
    try std.testing.expectEqualStrings(
        "OTEL_HTTP",
        otel.errorCode(otel.OtelError.OtelHttp),
    );
}
