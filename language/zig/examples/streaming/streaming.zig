const std = @import("std");

pub fn main() !void {
    const chunks = [_][]const u8{ "status: ", "green" };
    const output = try std.mem.concat(std.heap.page_allocator, u8, &chunks);
    defer std.heap.page_allocator.free(output);
    if (!std.mem.eql(u8, output, "status: green")) return error.StreamMismatch;
    std.debug.print("Zig streaming example passed\n", .{});
}
