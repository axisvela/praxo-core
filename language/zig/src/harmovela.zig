const std = @import("std");
const json = @import("json.zig");
const models = @import("models.zig");
const runtime = @import("runtime.zig");

const Allocator = std.mem.Allocator;

pub const SinkError = error{
    HarmovelaBaseUrlRequired,
    HarmovelaHttp,
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
    base_url: []const u8,
    source: []const u8 = "praxo-core",
    spec_version: []const u8 = "0.2",
    transport: ?Transport = null,
    clock: ?Clock = null,
    last_error: ?[]const u8 = null,

    pub fn init(allocator: Allocator, base_url: []const u8) Sink {
        return .{ .allocator = allocator, .base_url = base_url };
    }

    pub fn emit(self: *Sink, event: models.Event) !void {
        self.last_error = null;
        if (self.base_url.len == 0) return SinkError.HarmovelaBaseUrlRequired;
        const parts = if (self.clock) |clock| clock() else nowParts();
        var payload = std.json.ObjectMap.empty;
        if (event.data) |data| {
            if (data == .object) {
                var iterator = data.object.iterator();
                while (iterator.next()) |entry| {
                    try payload.put(self.allocator, entry.key_ptr.*, entry.value_ptr.*);
                }
            }
        }
        if (event.session_id.len > 0) {
            try payload.put(self.allocator, "session_id", .{ .string = event.session_id });
        }
        if (event.run_id) |run_id| {
            if (run_id.len > 0) {
                try payload.put(self.allocator, "run_id", .{ .string = run_id });
            }
        }
        var prefix: []const u8 = "event";
        if (event.session_id.len > 0) prefix = event.session_id;
        if (event.run_id) |run_id| {
            if (run_id.len > 0) prefix = run_id;
        }
        const identifier = try std.fmt.allocPrint(
            self.allocator,
            "{s}-{d}",
            .{ prefix, parts.seconds * 1_000_000_000 + @as(i64, parts.nanos) },
        );
        var root = std.json.ObjectMap.empty;
        try root.put(self.allocator, "spec_version", .{ .string = self.specVersion() });
        try root.put(self.allocator, "id", .{ .string = identifier });
        try root.put(self.allocator, "type", .{ .string = event.type });
        try root.put(self.allocator, "source", .{ .string = self.sourceValue() });
        try root.put(self.allocator, "created_at", .{ .string = try formatRfc3339(self.allocator, parts) });
        try root.put(self.allocator, "payload", .{ .object = payload });
        const body = try json.stringify(self.allocator, .{ .object = root });
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/events",
            .{std.mem.trimEnd(u8, self.base_url, "/")},
        );
        const request = HttpRequest{
            .method = "POST",
            .url = url,
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
                "harmovela: HTTP {d}: {s}",
                .{ response.status, bounded },
            );
            return SinkError.HarmovelaHttp;
        }
    }

    pub fn eventSink(self: *Sink) runtime.EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ctx: *anyopaque, event: models.Event) void {
        const self: *Sink = @ptrCast(@alignCast(ctx));
        self.emit(event) catch {};
    }

    fn sourceValue(self: *const Sink) []const u8 {
        if (self.source.len == 0) return "praxo-core";
        return self.source;
    }

    fn specVersion(self: *const Sink) []const u8 {
        if (self.spec_version.len == 0) return "0.2";
        return self.spec_version;
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

fn nowParts() TimeParts {
    const timestamp = std.Io.Clock.real.now(std.Io.Threaded.global_single_threaded.io());
    const per_second: i96 = std.time.ns_per_s;
    const seconds: i64 = @intCast(@divFloor(timestamp.nanoseconds, per_second));
    const nanos: u32 = @intCast(@mod(timestamp.nanoseconds, per_second));
    return .{ .seconds = seconds, .nanos = nanos };
}

fn formatRfc3339(allocator: Allocator, parts: TimeParts) ![]u8 {
    const days = @divFloor(parts.seconds, 86_400);
    const day_seconds = @mod(parts.seconds, 86_400);
    const civil = civilFromDays(days);
    const year = try padZeros(allocator, civil.year, 4);
    const month = try padZeros(allocator, civil.month, 2);
    const day = try padZeros(allocator, civil.day, 2);
    const hour = try padZeros(allocator, @divFloor(day_seconds, 3_600), 2);
    const minute = try padZeros(allocator, @divFloor(@mod(day_seconds, 3_600), 60), 2);
    const second = try padZeros(allocator, @mod(day_seconds, 60), 2);
    const nanos = try padZeros(allocator, parts.nanos, 9);
    return std.fmt.allocPrint(
        allocator,
        "{s}-{s}-{s}T{s}:{s}:{s}.{s}Z",
        .{ year, month, day, hour, minute, second, nanos },
    );
}

fn padZeros(allocator: Allocator, value: anytype, width: usize) ![]u8 {
    const raw = try std.fmt.allocPrint(allocator, "{d}", .{value});
    if (raw.len >= width) return raw;
    const output = try allocator.alloc(u8, width);
    @memset(output[0 .. width - raw.len], '0');
    @memcpy(output[width - raw.len ..], raw);
    return output;
}

const Civil = struct {
    year: i64,
    month: u32,
    day: u32,
};

fn civilFromDays(days: i64) Civil {
    const shifted = days + 719_468;
    const era = @divFloor(if (shifted >= 0) shifted else shifted - 146_096, 146_097);
    const day_of_era = shifted - era * 146_097;
    const year_of_era = @divFloor(
        day_of_era - @divFloor(day_of_era, 1_460) + @divFloor(day_of_era, 36_524) - @divFloor(day_of_era, 146_096),
        365,
    );
    const year = year_of_era + era * 400;
    const day_of_year = day_of_era - (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));
    const month_prime = @divFloor(5 * day_of_year + 2, 153);
    const day = day_of_year - @divFloor(153 * month_prime + 2, 5) + 1;
    const month = if (month_prime < 10) month_prime + 3 else month_prime - 9;
    return .{
        .year = if (month <= 2) year + 1 else year,
        .month = @intCast(month),
        .day = @intCast(day),
    };
}
