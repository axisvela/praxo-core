const std = @import("std");
const json = @import("json.zig");
const mcp = @import("mcp.zig");

const Fake = struct {
    allocator: std.mem.Allocator,
    closed: bool = false,
    notified: bool = false,

    fn transport(self: *Fake) mcp.Transport {
        return .{
            .ctx = self,
            .requestFn = request,
            .notifyFn = notify,
            .closeFn = close,
        };
    }

    fn request(
        ctx: *anyopaque,
        allocator: std.mem.Allocator,
        method: []const u8,
        params: json.Json,
        timeout_ms: u64,
    ) anyerror!json.Json {
        _ = ctx;
        _ = params;
        _ = timeout_ms;
        if (std.mem.eql(u8, method, "initialize")) {
            return json.parse(allocator,
                "{\"protocolVersion\":\"2025-03-26\",\"serverInfo\":{\"name\":\"fake\"}}");
        }
        if (std.mem.eql(u8, method, "tools/list")) {
            return json.parse(allocator,
                "{\"tools\":[{\"name\":\"echo\",\"inputSchema\":{\"type\":\"object\"}}]}");
        }
        if (std.mem.eql(u8, method, "tools/call")) {
            return json.parse(allocator,
                "{\"content\":[{\"type\":\"text\",\"text\":\"http-ok\"}]}");
        }
        return json.parse(allocator, "{}");
    }

    fn notify(
        ctx: *anyopaque,
        allocator: std.mem.Allocator,
        method: []const u8,
        params: json.Json,
    ) anyerror!void {
        _ = allocator;
        _ = method;
        _ = params;
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.notified = true;
    }

    fn close(ctx: *anyopaque) void {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.closed = true;
    }
};

test "client handshake, tools, call, close" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .allocator = allocator };
    var client = mcp.Client.init(
        allocator,
        fake.transport(),
        "2025-03-26",
        "0.2.0",
        5000,
    );
    try client.start();
    try std.testing.expectEqualStrings("2025-03-26", client.protocol_version);
    try std.testing.expect(fake.notified);

    const tools = try client.listTools();
    try std.testing.expectEqual(@as(usize, 1), tools.len);
    try std.testing.expectEqualStrings("echo", json.string(tools[0], "name").?);

    const result = try client.callTool("echo", .{ .object = .empty });
    try std.testing.expectEqualStrings("http-ok", result.string);

    client.close();
    try std.testing.expect(fake.closed);
}

test "plain remote HTTP is rejected" {
    try std.testing.expectError(
        mcp.McpError.McpTransport,
        mcp.HttpTransport.init(std.testing.allocator, "http://example.com/mcp"),
    );
}
