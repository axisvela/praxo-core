const std = @import("std");
const ids = @import("ids.zig");

const Allocator = std.mem.Allocator;

pub const SubagentError = error{
    SubagentInvalid,
};

pub const TimeParts = struct {
    seconds: i64,
    nanos: u32,
};

pub const Clock = *const fn () TimeParts;

pub const SubagentRequest = struct {
    parent_session_id: []const u8 = "",
    agent_id: []const u8 = "",
    prompt: []const u8 = "",
    mode: []const u8 = "isolated",
};

pub const SubagentResult = struct {
    task_id: []const u8 = "",
    agent_id: []const u8 = "",
    output: []const u8 = "",
};

pub const SubagentTask = struct {
    id: []const u8 = "",
    parent_session_id: []const u8 = "",
    agent_id: []const u8 = "",
    mode: []const u8 = "isolated",
    status: []const u8 = "",
    output: []const u8 = "",
    error: []const u8 = "",
    created_at: []const u8 = "",
    updated_at: []const u8 = "",
};

pub const RunFn = *const fn (
    ctx: *anyopaque,
    allocator: Allocator,
    request: SubagentRequest,
) anyerror!SubagentResult;

pub const SubagentRunner = struct {
    ctx: *anyopaque,
    runFn: RunFn,

    pub fn run(
        self: SubagentRunner,
        allocator: Allocator,
        request: SubagentRequest,
    ) !SubagentResult {
        return self.runFn(self.ctx, allocator, request);
    }
};

pub fn subagentRun(
    allocator: Allocator,
    runner: ?SubagentRunner,
    request: SubagentRequest,
    clock: ?Clock,
) !SubagentTask {
    const runner_value = runner orelse return SubagentError.SubagentInvalid;
    if (request.parent_session_id.len == 0 or request.agent_id.len == 0) {
        return SubagentError.SubagentInvalid;
    }
    const mode: []const u8 = if (std.mem.eql(u8, request.mode, "fork")) "fork" else "isolated";
    const created = try formatRfc3339(allocator, if (clock) |value| value() else nowParts());
    var task = SubagentTask{
        .id = try std.fmt.allocPrint(allocator, "subagent-{d}", .{ids.next()}),
        .parent_session_id = request.parent_session_id,
        .agent_id = request.agent_id,
        .mode = mode,
        .status = "running",
        .created_at = created,
        .updated_at = created,
    };
    const result = runner_value.run(allocator, request) catch |error_value| {
        task.status = "failed";
        task.error = errorCode(error_value);
        task.updated_at = try formatRfc3339(allocator, if (clock) |value| value() else nowParts());
        return task;
    };
    task.status = "completed";
    task.output = result.output;
    task.updated_at = try formatRfc3339(allocator, if (clock) |value| value() else nowParts());
    return task;
}

pub fn errorCode(error_value: anyerror) []const u8 {
    return switch (error_value) {
        SubagentError.SubagentInvalid => "SUBAGENT_INVALID",
        else => @errorName(error_value),
    };
}

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
