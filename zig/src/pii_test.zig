const std = @import("std");
const middleware = @import("middleware.zig");

test "pii" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const got = try middleware.PiiRedactor.redact(arena.allocator(), "email a@b.com");
    try std.testing.expectEqualStrings("email [REDACTED:email]", got);
}
