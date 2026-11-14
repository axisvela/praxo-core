const std = @import("std");

const Outcome = struct {
    output: ?[]const u8 = null,
    code: ?[]const u8 = null,
    calls: u32,
};

fn runRetry(failures: u32, max_attempts: u32) Outcome {
    var attempt: u32 = 1;
    while (attempt <= max_attempts) : (attempt += 1) {
        if (attempt > failures) {
            return .{ .output = "status: green", .calls = attempt };
        }
    }
    return .{ .code = "MODEL_UNAVAILABLE", .calls = max_attempts };
}

pub fn main() !void {
    const recovered = runRetry(2, 3);
    if (recovered.output == null or recovered.calls != 3) return error.TransientFailed;
    const exhausted = runRetry(3, 3);
    if (exhausted.code == null or exhausted.calls != 3) return error.ExhaustedFailed;
    std.debug.print("Zig retry example passed\n", .{});
}
