const std = @import("std");
const example = @import("hitl.zig");
const praxo = @import("praxo");
const agent = praxo.agent;

test "hitl example approves a public note" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var calls: usize = 0;
    var context = example.DecisionContext{ .decision = .{ .action = agent.INTERRUPT_APPROVE } };
    const output = try example.runScenario(arena.allocator(), &context, &calls);
    try std.testing.expectEqualStrings("done", output);
    try std.testing.expectEqual(@as(usize, 1), calls);
}

test "hitl example denies an edited private note before effect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var calls: usize = 0;
    var arguments = std.json.ObjectMap.empty;
    try arguments.put(arena.allocator(), "text", .{ .string = "hello" });
    try arguments.put(arena.allocator(), "visibility", .{ .string = "private" });
    var context = example.DecisionContext{ .decision = .{
        .action = agent.INTERRUPT_EDIT,
        .arguments = .{ .object = arguments },
    } };
    try std.testing.expectError(
        error.PolicyError,
        example.runScenario(arena.allocator(), &context, &calls),
    );
    try std.testing.expectEqual(@as(usize, 0), calls);
}
