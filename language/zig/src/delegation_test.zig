const std = @import("std");
const delegation = @import("delegation.zig");

fn completedRunner(
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    request: delegation.SubagentRequest,
) anyerror!delegation.SubagentResult {
    _ = ctx;
    _ = allocator;
    return .{ .agent_id = request.agent_id, .output = "done" };
}

fn failingRunner(
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    request: delegation.SubagentRequest,
) anyerror!delegation.SubagentResult {
    _ = ctx;
    _ = allocator;
    _ = request;
    return error.SUBAGENT_BOOM;
}

fn fixedClock() delegation.TimeParts {
    return .{ .seconds = 1_700_000_000, .nanos = 123_456_789 };
}

test "subagent run completes synchronously and preserves the terminal state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var context: u8 = 0;
    const runner = delegation.SubagentRunner{ .ctx = &context, .runFn = completedRunner };
    const task = try delegation.subagentRun(
        allocator,
        runner,
        .{
            .parent_session_id = "parent",
            .agent_id = "child",
            .prompt = "look up",
            .mode = "fork",
        },
        fixedClock,
    );
    try std.testing.expectEqualStrings("completed", task.status);
    try std.testing.expectEqualStrings("fork", task.mode);
    try std.testing.expectEqualStrings("done", task.output);
    try std.testing.expectEqualStrings("", task.error);
    try std.testing.expectEqualStrings("2023-11-14T22:13:20.123456789Z", task.created_at);
    try std.testing.expectEqualStrings("2023-11-14T22:13:20.123456789Z", task.updated_at);
}

test "subagent run fails terminally and preserves the runner error code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var context: u8 = 0;
    const runner = delegation.SubagentRunner{ .ctx = &context, .runFn = failingRunner };
    const task = try delegation.subagentRun(
        allocator,
        runner,
        .{ .parent_session_id = "parent", .agent_id = "child" },
        fixedClock,
    );
    try std.testing.expectEqualStrings("failed", task.status);
    try std.testing.expectEqualStrings("SUBAGENT_BOOM", task.error);
}

test "subagent run requires parent session and agent ids" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var context: u8 = 0;
    const runner = delegation.SubagentRunner{ .ctx = &context, .runFn = completedRunner };
    try std.testing.expectError(
        delegation.SubagentError.SubagentInvalid,
        delegation.subagentRun(
            allocator,
            runner,
            .{ .parent_session_id = "", .agent_id = "child" },
            null,
        ),
    );
    try std.testing.expectError(
        delegation.SubagentError.SubagentInvalid,
        delegation.subagentRun(
            allocator,
            runner,
            .{ .parent_session_id = "parent", .agent_id = "" },
            null,
        ),
    );
    try std.testing.expectEqualStrings(
        "SUBAGENT_INVALID",
        delegation.errorCode(delegation.SubagentError.SubagentInvalid),
    );
}
