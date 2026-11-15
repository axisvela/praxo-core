const std = @import("std");
const agent = @import("agent.zig");
const models = @import("models.zig");
const testing = std.testing;

fn allowPolicy(ctx: *anyopaque, action: models.Action) models.Decision {
    _ = ctx;
    _ = action;
    return .{ .allowed = true };
}

test "safe-default guards are off by default" {
    var static_model = agent.StaticModel{ .content = "ok" };
    const options = agent.AgentOptions{ .model = static_model.model() };
    try testing.expect(!options.require_policy);
    try testing.expect(!options.require_tool_scope);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var instance = agent.Agent.init(options);
    const result = try instance.run(arena.allocator(), .{ .id = "s1" }, "go");
    try testing.expectEqualStrings("ok", result.output);
}

test "require policy rejects a missing policy" {
    var static_model = agent.StaticModel{ .content = "ok" };
    const options = agent.AgentOptions{
        .model = static_model.model(),
        .require_policy = true,
    };
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var instance = agent.Agent.init(options);
    try testing.expectError(
        agent.AgentError.AgentInvalidOptions,
        instance.run(arena.allocator(), .{ .id = "s1" }, "go"),
    );
}

test "require policy accepts a configured policy" {
    var static_model = agent.StaticModel{ .content = "ok" };
    var policy_context: u8 = 0;
    const options = agent.AgentOptions{
        .model = static_model.model(),
        .policy = allowPolicy,
        .policy_ctx = @ptrCast(&policy_context),
        .require_policy = true,
    };
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var instance = agent.Agent.init(options);
    const result = try instance.run(arena.allocator(), .{ .id = "s1" }, "go");
    try testing.expectEqualStrings("ok", result.output);
}

test "require tool scope rejects an empty allowed list" {
    var static_model = agent.StaticModel{ .content = "ok" };
    const options = agent.AgentOptions{
        .model = static_model.model(),
        .require_tool_scope = true,
    };
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var instance = agent.Agent.init(options);
    try testing.expectError(
        agent.AgentError.AgentInvalidOptions,
        instance.run(arena.allocator(), .{ .id = "s1" }, "go"),
    );
}

test "require tool scope accepts a non-empty allowed list" {
    var static_model = agent.StaticModel{ .content = "ok" };
    const allowed = [_][]const u8{"echo"};
    const options = agent.AgentOptions{
        .model = static_model.model(),
        .allowed_tools = &allowed,
        .require_tool_scope = true,
    };
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var instance = agent.Agent.init(options);
    const result = try instance.run(arena.allocator(), .{ .id = "s1" }, "go");
    try testing.expectEqualStrings("ok", result.output);
}
