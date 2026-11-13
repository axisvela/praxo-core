const std = @import("std");
const json = @import("json.zig");
const models = @import("models.zig");
const runtime = @import("runtime.zig");

const Allocator = std.mem.Allocator;

pub const OtelError = error{
    OtelEndpointRequired,
    OtelHttp,
};

pub const TransportResult = struct {
    status: u16,
    body: []const u8,
};

pub const HttpRequest = struct {
    method: []const u8,
    url: []const u8,
    content_type: []const u8,
    body: []const u8,
};

pub const Transport = struct {
    ctx: *anyopaque,
    sendFn: *const fn (ctx: *anyopaque, allocator: Allocator, request: HttpRequest) anyerror!TransportResult,

    pub fn send(self: Transport, allocator: Allocator, request: HttpRequest) !TransportResult {
        return self.sendFn(self.ctx, allocator, request);
    }
};

pub const TimeParts = struct {
    seconds: i64,
    nanos: u32,
};

pub const Clock = *const fn () TimeParts;

pub const Sink = struct {
    allocator: Allocator,
    endpoint: []const u8,
    service_name: []const u8 = "praxo-core",
    allowed_data_keys: []const []const u8 = &.{},
    transport: ?Transport = null,
    clock: ?Clock = null,
    last_error: ?[]const u8 = null,

    pub fn init(allocator: Allocator, endpoint: []const u8) Sink {
        return .{
            .allocator = allocator,
            .endpoint = std.mem.trim(u8, endpoint, " \t\r\n"),
        };
    }

    pub fn emit(self: *Sink, event: models.Event) !void {
        self.last_error = null;
        if (self.endpoint.len == 0) return OtelError.OtelEndpointRequired;
        const parts = if (self.clock) |clock| clock() else nowParts();
        const body = try json.stringify(self.allocator, try self.payload(event, parts));
        const request = HttpRequest{
            .method = "POST",
            .url = self.endpoint,
            .content_type = "application/json",
            .body = body,
        };
        const response = if (self.transport) |transport|
            try transport.send(self.allocator, request)
        else
            try self.post(request);
        if (response.status < 200 or response.status >= 300) {
            const bounded = response.body[0..@min(response.body.len, 512)];
            self.last_error = try std.fmt.allocPrint(
                self.allocator,
                "otel: HTTP {d}: {s}",
                .{ response.status, bounded },
            );
            return OtelError.OtelHttp;
        }
    }

    pub fn eventSink(self: *Sink) runtime.EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ctx: *anyopaque, event: models.Event) void {
        const self: *Sink = @ptrCast(@alignCast(ctx));
        self.emit(event) catch {};
    }

    fn payload(self: *const Sink, event: models.Event, parts: TimeParts) !json.Json {
        const nanos = parts.seconds * 1_000_000_000 + @as(i64, parts.nanos);
        const data_text: []const u8 = if (event.data) |data|
            try json.stringify(self.allocator, data)
        else
            "";
        const key = try std.fmt.allocPrint(
            self.allocator,
            "{s}|{s}|{s}|{d}|{s}",
            .{ event.session_id, event.run_id orelse "", event.type, nanos, data_text },
        );
        const trace_id = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{
                try hexId(self.allocator, stableHash("trace-a:", key)),
                try hexId(self.allocator, stableHash("trace-b:", key)),
            },
        );
        const span_id = try hexId(self.allocator, stableHash("span:", key));

        var attributes = std.json.Array.init(self.allocator);
        try attributes.append(try attribute(self.allocator, "praxo.event.type", event.type));
        if (event.session_id.len > 0) {
            try attributes.append(try attribute(self.allocator, "praxo.session.id", event.session_id));
        }
        if (event.run_id) |run_id| {
            if (run_id.len > 0) {
                try attributes.append(try attribute(self.allocator, "praxo.run.id", run_id));
            }
        }
        try attributes.append(try attribute(
            self.allocator,
            "praxo.event.at",
            try std.fmt.allocPrint(self.allocator, "{d}", .{nanos}),
        ));
        if (event.data) |data| {
            if (data == .object) {
                for (self.allowed_data_keys) |name| {
                    if (data.object.get(name)) |value| {
                        const data_key = try std.fmt.allocPrint(
                            self.allocator,
                            "praxo.event.data.{s}",
                            .{name},
                        );
                        try attributes.append(try attribute(
                            self.allocator,
                            data_key,
                            try textValue(self.allocator, value),
                        ));
                    }
                }
            }
        }

        const span_name = try std.fmt.allocPrint(self.allocator, "praxo.{s}", .{event.type});
        var span = std.json.ObjectMap.empty;
        try span.put(self.allocator, "traceId", .{ .string = trace_id });
        try span.put(self.allocator, "spanId", .{ .string = span_id });
        try span.put(self.allocator, "name", .{ .string = span_name });
        try span.put(self.allocator, "kind", .{ .integer = 1 });
        try span.put(self.allocator, "startTimeUnixNano", .{ .string = try std.fmt.allocPrint(self.allocator, "{d}", .{nanos}) });
        try span.put(self.allocator, "endTimeUnixNano", .{ .string = try std.fmt.allocPrint(self.allocator, "{d}", .{nanos}) });
        try span.put(self.allocator, "attributes", .{ .array = attributes });

        var spans = std.json.Array.init(self.allocator);
        try spans.append(.{ .object = span });

        var scope = std.json.ObjectMap.empty;
        try scope.put(self.allocator, "name", .{ .string = "praxo-core" });
        try scope.put(self.allocator, "spans", .{ .array = spans });

        var scope_spans = std.json.Array.init(self.allocator);
        try scope_spans.append(.{ .object = scope });

        var resource_attributes = std.json.Array.init(self.allocator);
        try resource_attributes.append(try attribute(
            self.allocator,
            "service.name",
            self.serviceValue(),
        ));

        var resource = std.json.ObjectMap.empty;
        try resource.put(self.allocator, "attributes", .{ .array = resource_attributes });

        var resource_span = std.json.ObjectMap.empty;
        try resource_span.put(self.allocator, "resource", .{ .object = resource });
        try resource_span.put(self.allocator, "scopeSpans", .{ .array = scope_spans });

        var resource_spans = std.json.Array.init(self.allocator);
        try resource_spans.append(.{ .object = resource_span });

        var root = std.json.ObjectMap.empty;
        try root.put(self.allocator, "resourceSpans", .{ .array = resource_spans });
        return .{ .object = root };
    }

    fn serviceValue(self: *const Sink) []const u8 {
        if (self.service_name.len == 0) return "praxo-core";
        return self.service_name;
    }

    fn post(self: *Sink, request: HttpRequest) !TransportResult {
        var output = std.Io.Writer.Allocating.init(self.allocator);
        defer output.deinit();
        var client = std.http.Client{
            .allocator = self.allocator,
            .io = std.Io.Threaded.global_single_threaded.io(),
        };
        defer client.deinit();
        const headers = [_]std.http.Header{
            .{ .name = "content-type", .value = request.content_type },
        };
        const response = try client.fetch(.{
            .location = .{ .url = request.url },
            .method = .POST,
            .payload = request.body,
            .extra_headers = &headers,
            .response_writer = &output.writer,
        });
        return .{
            .status = @intFromEnum(response.status),
            .body = try output.toOwnedSlice(),
        };
    }
};

pub fn errorCode(error_value: anyerror) []const u8 {
    return switch (error_value) {
        OtelError.OtelEndpointRequired => "OTEL_URL",
        OtelError.OtelHttp => "OTEL_HTTP",
        else => "",
    };
}

fn attribute(allocator: Allocator, key: []const u8, value: []const u8) !json.Json {
    var wrapped = std.json.ObjectMap.empty;
    try wrapped.put(allocator, "stringValue", .{ .string = value });
    var item = std.json.ObjectMap.empty;
    try item.put(allocator, "key", .{ .string = key });
    try item.put(allocator, "value", .{ .object = wrapped });
    return .{ .object = item };
}

fn textValue(allocator: Allocator, value: json.Json) ![]const u8 {
    return switch (value) {
        .string => |text| text,
        else => try json.stringify(allocator, value),
    };
}

fn stableHash(prefix: []const u8, text: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (prefix) |byte| {
        hash ^= @as(u64, byte);
        hash = hash *% 0x100000001b3;
    }
    for (text) |byte| {
        hash ^= @as(u64, byte);
        hash = hash *% 0x100000001b3;
    }
    return hash;
}

fn hexId(allocator: Allocator, value: u64) ![]u8 {
    const digits = "0123456789abcdef";
    const output = try allocator.alloc(u8, 16);
    var remaining = value;
    var index: usize = 16;
    while (index > 0) {
        index -= 1;
        output[index] = digits[@intCast(remaining & 0x0f)];
        remaining >>= 4;
    }
    return output;
}

fn nowParts() TimeParts {
    const timestamp = std.Io.Clock.real.now(std.Io.Threaded.global_single_threaded.io());
    const per_second: i96 = std.time.ns_per_s;
    const seconds: i64 = @intCast(@divFloor(timestamp.nanoseconds, per_second));
    const nanos: u32 = @intCast(@mod(timestamp.nanoseconds, per_second));
    return .{ .seconds = seconds, .nanos = nanos };
}
