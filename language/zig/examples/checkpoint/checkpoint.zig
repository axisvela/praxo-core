const std = @import("std");
const json = @import("json");
const runtime = @import("runtime");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var allow = runtime.CheckpointAllowlist.init(allocator);
    try allow.register("order");
    const value = try json.parse(allocator, "{\"value\":\"x\"}");
    const data = try allow.marshal("order", value);
    const decoded = try allow.unmarshal(data);
    if (!json.equals(decoded, value)) return error.CheckpointMismatch;
    std.debug.print("Zig checkpoint example passed\n", .{});
}
