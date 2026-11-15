const std = @import("std");
const agent = @import("agent.zig");
const json = @import("json.zig");
const models = @import("models.zig");
const runtime = @import("runtime.zig");
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

const HitlModel = struct {
    allocator: std.mem.Allocator,

    fn model(self: *HitlModel) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *HitlModel = @ptrCast(@alignCast(ctx));
        if (request.messages.len > 0) {
            const last = request.messages[request.messages.len - 1];
            if (std.mem.eql(u8, last.role, models.TOOL)) {
                return .{ .message = .{ .role = models.ASSISTANT, .content = "done" } };
            }
        }
        var arguments = std.json.ObjectMap.empty;
        try arguments.put(self.allocator, "text", .{ .string = "hello" });
        try arguments.put(self.allocator, "visibility", .{ .string = "public" });
        const calls = try self.allocator.alloc(models.ToolCall, 1);
        calls[0] = .{
            .id = "write-note-1",
            .name = "write_note",
            .arguments = .{ .object = arguments },
        };
        return .{ .message = .{
            .role = models.ASSISTANT,
            .content = "",
            .tool_calls = calls,
        } };
    }
};

const WriteTool = struct {
    calls: *usize,
};

fn writeInvoke(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    _ = arguments;
    const self: *WriteTool = @ptrCast(@alignCast(ctx));
    self.calls.* += 1;
    return .{ .string = "written" };
}

fn hitlPolicy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) {
        return .{ .allowed = true };
    }
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        if (!std.mem.eql(u8, name, "write_note")) {
            return .{ .allowed = false, .reason = "only write_note is permitted" };
        }
        const visibility = if (action.arguments) |arguments|
            json.string(arguments, "visibility") orelse ""
        else
            "";
        return .{
            .allowed = std.mem.eql(u8, visibility, "public"),
            .reason = "only public notes are permitted",
        };
    }
    return .{ .allowed = false, .reason = "unsupported action" };
}

const DecisionContext = struct {
    decision: agent.InterruptDecision,
};

fn decide(ctx: *anyopaque, _: agent.Interrupt) agent.InterruptDecision {
    const self: *DecisionContext = @ptrCast(@alignCast(ctx));
    return self.decision;
}

const HitlRecordingSink = struct {
    types: std.array_list.Managed([]const u8),

    fn init(allocator: std.mem.Allocator) HitlRecordingSink {
        return .{ .types = std.array_list.Managed([]const u8).init(allocator) };
    }

    fn sink(self: *HitlRecordingSink) runtime.EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ctx: *anyopaque, event: models.Event) void {
        const self: *HitlRecordingSink = @ptrCast(@alignCast(ctx));
        self.types.append(event.type) catch {};
    }
};

const HitlResult = struct {
    output: []const u8 = "",
    calls: usize = 0,
    failure: ?anyerror = null,
    events: []const []const u8 = &.{},
};

fn runHitl(allocator: std.mem.Allocator, decision: agent.InterruptDecision, with_handler: bool) !HitlResult {
    var calls: usize = 0;
    var tool = WriteTool{ .calls = &calls };
    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = &tool,
        .name = "write_note",
        .description = "Write a short note with the requested visibility.",
        .invokeFn = writeInvoke,
    });
    var model = HitlModel{ .allocator = allocator };
    var sink = HitlRecordingSink.init(allocator);
    const allowed = [_][]const u8{"write_note"};
    const interrupt_on = [_][]const u8{"write_note"};
    var decision_context = DecisionContext{ .decision = decision };
    var options = agent.AgentOptions{
        .model = model.model(),
        .tools = &registry,
        .events = sink.sink(),
        .max_steps = 3,
        .allowed_tools = &allowed,
        .interrupt_on = &interrupt_on,
        .policy = hitlPolicy,
        .policy_ctx = @ptrCast(&tool),
    };
    if (with_handler) {
        options.on_interrupt_decision = .{ .ctx = &decision_context, .decideFn = decide };
    }
    var instance = agent.Agent.init(options);
    var outcome = HitlResult{ .calls = calls, .events = sink.types.items };
    if (instance.run(allocator, .{ .id = "hitl" }, "Write a note.")) |result| {
        outcome.output = result.output;
    } else |failure| {
        outcome.failure = failure;
    }
    outcome.calls = calls;
    outcome.events = sink.types.items;
    return outcome;
}

test "hitl approve continues and invokes the tool" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const outcome = try runHitl(arena.allocator(), .{ .action = agent.INTERRUPT_APPROVE }, true);
    try testing.expect(outcome.failure == null);
    try testing.expectEqualStrings("done", outcome.output);
    try testing.expectEqual(@as(usize, 1), outcome.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "tool.interrupt", "tool.call", "run.completed" },
        outcome.events,
    );
}

test "hitl edit reauthorizes edited arguments and denies before effect" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var arguments = std.json.ObjectMap.empty;
    try arguments.put(arena.allocator(), "text", .{ .string = "hello" });
    try arguments.put(arena.allocator(), "visibility", .{ .string = "private" });
    const outcome = try runHitl(arena.allocator(), .{
        .action = agent.INTERRUPT_EDIT,
        .arguments = .{ .object = arguments },
    }, true);
    try testing.expect(outcome.failure.? == error.PolicyError);
    try testing.expectEqual(@as(usize, 0), outcome.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "tool.interrupt", "run.failed" },
        outcome.events,
    );
}

test "hitl reject raises approval denied" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const outcome = try runHitl(arena.allocator(), .{
        .action = agent.INTERRUPT_REJECT,
        .reason = "not allowed",
    }, true);
    try testing.expect(outcome.failure.? == agent.AgentError.AgentApprovalDenied);
    try testing.expectEqual(@as(usize, 0), outcome.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "tool.interrupt", "run.failed" },
        outcome.events,
    );
}

test "hitl respond skips the tool and uses the response" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const outcome = try runHitl(arena.allocator(), .{
        .action = agent.INTERRUPT_RESPOND,
        .response = "skipped",
    }, true);
    try testing.expect(outcome.failure == null);
    try testing.expectEqualStrings("done", outcome.output);
    try testing.expectEqual(@as(usize, 0), outcome.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "tool.interrupt", "run.completed" },
        outcome.events,
    );
}

test "hitl unhandled interrupt fails before emitting an interrupt" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const outcome = try runHitl(arena.allocator(), .{ .action = "" }, false);
    try testing.expect(outcome.failure.? == agent.AgentError.AgentInterruptUnhandled);
    try testing.expectEqual(@as(usize, 0), outcome.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "run.failed" },
        outcome.events,
    );
}

test "hitl invalid decisions fail without effects" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const unknown = try runHitl(arena.allocator(), .{ .action = "bogus" }, true);
    try testing.expect(unknown.failure.? == agent.AgentError.AgentInterruptDecisionInvalid);
    try testing.expectEqual(@as(usize, 0), unknown.calls);

    const missing = try runHitl(arena.allocator(), .{ .action = agent.INTERRUPT_EDIT }, true);
    try testing.expect(missing.failure.? == agent.AgentError.AgentInterruptDecisionInvalid);
    try testing.expectEqual(@as(usize, 0), missing.calls);
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "run.started", "tool.interrupt", "run.failed" },
        missing.events,
    );
}
