const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const json = praxo.json;
const models = praxo.models;

const WriteTool = struct {
    calls: *usize,
};

fn writeInvoke(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    _ = arguments;
    const self: *WriteTool = @ptrCast(@alignCast(ctx));
    self.calls.* += 1;
    return .{ .string = "written" };
}

const Fixture = struct {
    allocator: std.mem.Allocator,

    fn model(self: *Fixture) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *Fixture = @ptrCast(@alignCast(ctx));
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

fn allowPublic(_: *anyopaque, action: models.Action) models.Decision {
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

pub const DecisionContext = struct {
    decision: agent.InterruptDecision,
};

fn decide(ctx: *anyopaque, _: agent.Interrupt) agent.InterruptDecision {
    const self: *DecisionContext = @ptrCast(@alignCast(ctx));
    return self.decision;
}

pub fn runScenario(
    allocator: std.mem.Allocator,
    decision_context: *DecisionContext,
    calls: *usize,
) ![]const u8 {
    var tool = WriteTool{ .calls = calls };
    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = &tool,
        .name = "write_note",
        .description = "Write a short note with the requested visibility.",
        .invokeFn = writeInvoke,
    });
    var fixture = Fixture{ .allocator = allocator };
    const allowed = [_][]const u8{"write_note"};
    const interrupt_on = [_][]const u8{"write_note"};
    var instance = agent.Agent.init(.{
        .model = fixture.model(),
        .tools = &registry,
        .max_steps = 3,
        .allowed_tools = &allowed,
        .interrupt_on = &interrupt_on,
        .on_interrupt_decision = .{ .ctx = decision_context, .decideFn = decide },
        .policy = allowPublic,
        .policy_ctx = @ptrCast(&tool),
    });
    const result = try instance.run(allocator, .{ .id = "hitl" }, "Write a note.");
    return result.output;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var approve_calls: usize = 0;
    var approve_context = DecisionContext{ .decision = .{ .action = agent.INTERRUPT_APPROVE } };
    const approve_output = try runScenario(allocator, &approve_context, &approve_calls);
    if (!std.mem.eql(u8, approve_output, "done") or approve_calls != 1) {
        std.debug.print(
            "approve verification failed: output={s} effects={d}\n",
            .{ approve_output, approve_calls },
        );
        return error.ApproveVerificationFailed;
    }
    std.debug.print("approve: written; effects=1\n", .{});

    var edit_calls: usize = 0;
    var edit_arguments = std.json.ObjectMap.empty;
    try edit_arguments.put(allocator, "text", .{ .string = "hello" });
    try edit_arguments.put(allocator, "visibility", .{ .string = "private" });
    var edit_context = DecisionContext{ .decision = .{
        .action = agent.INTERRUPT_EDIT,
        .arguments = .{ .object = edit_arguments },
    } };
    if (runScenario(allocator, &edit_context, &edit_calls)) |_| {
        std.debug.print("edited private note was not denied\n", .{});
        return error.EditWasNotDenied;
    } else |failure| {
        if (failure != error.PolicyError or edit_calls != 0) {
            std.debug.print(
                "edit verification failed: code={s} effects={d}\n",
                .{ @errorName(failure), edit_calls },
            );
            return error.EditVerificationFailed;
        }
    }
    std.debug.print("edit: policy rejected; effects=0\n", .{});
}
