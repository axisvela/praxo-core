const std = @import("std");
const example = @import("starter.zig");

test "session checkpoint restores four messages and continues to turn five" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const outcome = try example.run(arena.allocator());
    try std.testing.expectEqual(@as(usize, 4), outcome.restored_messages);
    try std.testing.expectEqualStrings("turn 5", outcome.output);
}
