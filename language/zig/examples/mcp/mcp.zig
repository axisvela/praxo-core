const std = @import("std");
const json = @import("json");
const mcp = @import("mcp");

var context: u8 = 0;

fn request(
    _: *anyopaque,
    allocator: std.mem.Allocator,
    method: []const u8,
    _: json.Json,
    _: u64,
) !json.Json {
    if (std.mem.eql(u8, method, "initialize")) {
        return json.parse(allocator, "{\"protocolVersion\":\"2024-11-05\",\"serverInfo\":{\"name\":\"example-mcp\"}}");
    }
    if (std.mem.eql(u8, method, "tools/list")) {
        return json.parse(allocator, "{\"tools\":[{\"name\":\"echo\",\"inputSchema\":{\"type\":\"object\"}},{\"name\":\"add\",\"inputSchema\":{\"type\":\"object\"}}]}");
    }
    if (std.mem.eql(u8, method, "tools/call")) {
        return json.parse(allocator, "{\"structuredContent\":{\"sum\":5}}");
    }
    return json.parse(allocator, "{}");
}

fn notify(_: *anyopaque, _: std.mem.Allocator, _: []const u8, _: json.Json) !void {}
fn close(_: *anyopaque) void {}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const transport = mcp.Transport{
        .ctx = @ptrCast(&context),
        .requestFn = request,
        .notifyFn = notify,
        .closeFn = close,
    };
    var client = mcp.Client.init(allocator, transport, "2024-11-05", "0.0.0", 1000);
    try client.start();
    const tools = try client.listTools();
    const result = try client.callTool("add", .{ .object = .empty });
    client.close();
    if (tools.len != 2 or result != .object) return error.McpMismatch;
    std.debug.print("Zig MCP example passed\n", .{});
}
