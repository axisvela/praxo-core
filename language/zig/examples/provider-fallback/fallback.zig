const std = @import("std");

fn runFallback(primary_fails: bool, fallback_fails: bool) []const u8 {
    if (!primary_fails) return "primary";
    if (!fallback_fails) return "fallback";
    return "MODEL_UNAVAILABLE";
}

pub fn main() !void {
    if (!std.mem.eql(u8, runFallback(false, false), "primary")) return error.PrimaryFailed;
    if (!std.mem.eql(u8, runFallback(true, false), "fallback")) return error.FallbackFailed;
    if (!std.mem.eql(u8, runFallback(true, true), "MODEL_UNAVAILABLE")) return error.BothFailed;
    std.debug.print("Zig provider fallback example passed\n", .{});
}
