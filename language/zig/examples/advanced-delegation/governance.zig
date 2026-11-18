const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const delegation = praxo.delegation;
const models = praxo.models;
const json = praxo.json;

const Allocator = std.mem.Allocator;

const GovState = struct {
    allocator: Allocator,
    effects: std.StringHashMap(i64),
    budget: i64 = 0,
    children: i64 = 0,

    fn init(allocator: Allocator) GovState {
        return .{ .allocator = allocator, .effects = std.StringHashMap(i64).init(allocator) };
    }
};

const RunConfig = struct {
    allowed: []const []const u8,
    policy: *const fn (*anyopaque, models.Action) models.Decision,
    policy_ctx: *anyopaque,
    depth: i64 = 0,
    max_depth: i64 = -1,
    max_children: i64 = -1,
    use_budget: bool = false,
    use_children: bool = false,
    cancelled: bool = false,
    edit_to_blocked: bool = false,
};

const ModelContext = struct {
    allocator: Allocator,
    steps: std.array_list.Managed(models.Response),
    final_content: []const u8,

    fn init(allocator: Allocator, steps: []const models.Response, final_content: []const u8) ModelContext {
        var list = std.array_list.Managed(models.Response).init(allocator);
        list.appendSlice(steps) catch unreachable;
        return .{ .allocator = allocator, .steps = list, .final_content = final_content };
    }

    fn model(self: *ModelContext) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = request;
        const self: *ModelContext = @ptrCast(@alignCast(ctx));
        if (self.steps.items.len > 0) {
            const step = self.steps.items[0];
            _ = self.steps.orderedRemove(0);
            return step;
        }
        return .{ .message = .{ .role = models.ASSISTANT, .content = self.final_content } };
    }
};

fn toolResponse(allocator: Allocator, call: models.ToolCall) !models.Response {
    const calls = try allocator.alloc(models.ToolCall, 1);
    calls[0] = call;
    return .{ .message = .{ .role = models.ASSISTANT, .content = "", .tool_calls = calls } };
}

fn callFor(allocator: Allocator, tool: []const u8, target: []const u8) !models.ToolCall {
    var arguments = std.json.ObjectMap.empty;
    try arguments.put(allocator, "target", .{ .string = target });
    return .{ .id = "call-1", .name = tool, .arguments = .{ .object = arguments } };
}

const ToolContext = struct {
    state: *GovState,
};

fn invokeEffect(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *ToolContext = @ptrCast(@alignCast(ctx));
    const target = json.string(arguments, "target") orelse "";
    self.state.effects.put(target, (self.state.effects.get(target) orelse 0) + 1) catch {};
    return .{ .string = "ok" };
}

fn allow() models.Decision {
    return .{ .allowed = true, .reason = "" };
}

fn deny(reason: []const u8) models.Decision {
    return .{ .allowed = false, .reason = reason };
}

fn targetOf(action: models.Action) []const u8 {
    const arguments = action.arguments orelse return "";
    return json.string(arguments, "target") orelse "";
}

fn permissiveRecord(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return allow();
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return deny("missing tool");
        if (std.mem.eql(u8, name, "record")) return allow();
    }
    return deny("child may only record");
}

fn parentBlocked(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return allow();
    if (!std.mem.eql(u8, action.kind, "tool.invoke")) return deny("unsupported action");
    const name = action.tool_name orelse return deny("missing tool");
    if (!std.mem.eql(u8, name, "record")) return deny("parent tool is not allowed");
    if (std.mem.eql(u8, targetOf(action), "blocked")) return deny("blocked target");
    return allow();
}

fn composedPolicy(ctx: *anyopaque, action: models.Action) models.Decision {
    const parent = parentBlocked(ctx, action);
    if (!parent.allowed) return parent;
    return permissiveRecord(ctx, action);
}

fn interruptDecide(_: *anyopaque, interrupt: agent.Interrupt) agent.InterruptDecision {
    _ = interrupt;
    var arguments = std.json.ObjectMap.empty;
    arguments.put(std.heap.page_allocator, "target", .{ .string = "blocked" }) catch unreachable;
    return .{ .action = agent.INTERRUPT_EDIT, .arguments = .{ .object = arguments } };
}

fn deniedTask(status: []const u8, code: []const u8) delegation.SubagentTask {
    return .{
        .id = "subagent",
        .parent_session_id = "governance-parent",
        .agent_id = "governance-child",
        .mode = "isolated",
        .status = status,
        .output = "",
        .@"error" = code,
        .created_at = "",
        .updated_at = "",
    };
}

const ChildContext = struct {
    options: agent.AgentOptions,
};

fn runChildFn(ctx: *anyopaque, allocator: Allocator, request: delegation.SubagentRequest) anyerror!delegation.SubagentResult {
    _ = request;
    const self: *ChildContext = @ptrCast(@alignCast(ctx));
    const result = try agent.runAgent(allocator, self.options, .{ .id = "governance-child" }, "run child");
    return .{ .task_id = "child", .agent_id = "child", .output = result.output };
}

fn runChild(allocator: Allocator, state: *GovState, model: agent.Model, config: RunConfig) !delegation.SubagentTask {
    if (config.cancelled) return deniedTask("cancelled", "CANCELLED");
    if (config.max_depth >= 0 and config.depth > config.max_depth) return deniedTask("denied", "DEPTH_LIMIT");
    if (config.max_children >= 0 and state.children >= config.max_children) return deniedTask("denied", "CHILD_LIMIT");
    if (config.use_budget and state.budget <= 0) return deniedTask("denied", "BUDGET_EXHAUSTED");
    if (config.use_children) state.children += 1;

    var tool_context = ToolContext{ .state = state };
    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = @ptrCast(&tool_context),
        .name = "record",
        .description = "record",
        .invokeFn = invokeEffect,
    });
    try registry.register(.{
        .ctx = @ptrCast(&tool_context),
        .name = "write",
        .description = "write",
        .invokeFn = invokeEffect,
    });
    const interrupt_on = [_][]const u8{"record"};
    const options = agent.AgentOptions{
        .model = model,
        .tools = &registry,
        .max_steps = 3,
        .allowed_tools = config.allowed,
        .policy = config.policy,
        .policy_ctx = config.policy_ctx,
        .require_policy = true,
        .require_tool_scope = true,
        .interrupt_on = if (config.edit_to_blocked) &interrupt_on else &.{},
        .on_interrupt_decision = if (config.edit_to_blocked)
            .{ .ctx = @ptrCast(state), .decideFn = interruptDecide }
        else
            null,
    };
    var child_context = ChildContext{ .options = options };
    const task = try delegation.subagentRun(
        allocator,
        .{ .ctx = @ptrCast(&child_context), .runFn = runChildFn },
        .{
            .parent_session_id = "governance-parent",
            .agent_id = "governance-child",
            .prompt = "run child",
            .mode = "isolated",
        },
        null,
    );
    if (config.use_budget and std.mem.eql(u8, task.status, "completed")) state.budget -= 1;
    return task;
}

fn modelFor(allocator: Allocator, tool: []const u8, target: []const u8) !ModelContext {
    var list = std.array_list.Managed(models.Response).init(allocator);
    try list.append(try toolResponse(allocator, try callFor(allocator, tool, target)));
    try list.append(.{ .message = .{ .role = models.ASSISTANT, .content = "done" } });
    return .{ .allocator = allocator, .steps = list, .final_content = "done" };
}

fn effectCount(state: *GovState, name: []const u8) i64 {
    return state.effects.get(name) orelse 0;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var scope_state = GovState.init(allocator);
    var scope_model = try modelFor(allocator, "write", "escape");
    const scope = try runChild(allocator, &scope_state, scope_model.model(), .{
        .allowed = &.{"record"},
        .policy = permissiveRecord,
        .policy_ctx = @ptrCast(&scope_state),
    });
    if (!std.mem.eql(u8, scope.status, "failed")) return error.ScopeTest;
    if (effectCount(&scope_state, "escape") != 0) return error.ScopeEffect;

    var policy_state = GovState.init(allocator);
    var policy_model = try modelFor(allocator, "record", "blocked");
    const composed = try runChild(allocator, &policy_state, policy_model.model(), .{
        .allowed = &.{"record"},
        .policy = composedPolicy,
        .policy_ctx = @ptrCast(&policy_state),
    });
    if (!std.mem.eql(u8, composed.status, "failed")) return error.PolicyTest;
    if (effectCount(&policy_state, "blocked") != 0) return error.PolicyEffect;

    var budget_state = GovState.init(allocator);
    budget_state.budget = 1;
    var budget_model = try modelFor(allocator, "record", "sibling");
    const budget_config = RunConfig{
        .allowed = &.{"record"},
        .policy = permissiveRecord,
        .policy_ctx = @ptrCast(&budget_state),
        .use_budget = true,
    };
    const first = try runChild(allocator, &budget_state, budget_model.model(), budget_config);
    const second = try runChild(allocator, &budget_state, budget_model.model(), budget_config);
    if (!std.mem.eql(u8, first.status, "completed")) return error.BudgetFirst;
    if (!std.mem.eql(u8, second.status, "denied") or !std.mem.eql(u8, second.@"error", "BUDGET_EXHAUSTED")) return error.BudgetSecond;
    if (effectCount(&budget_state, "sibling") != 1) return error.BudgetEffect;

    var limit_state = GovState.init(allocator);
    var limit_model = try modelFor(allocator, "record", "limit");
    const limit_config = RunConfig{
        .allowed = &.{"record"},
        .policy = permissiveRecord,
        .policy_ctx = @ptrCast(&limit_state),
        .max_children = 1,
        .use_children = true,
    };
    const first_limit = try runChild(allocator, &limit_state, limit_model.model(), limit_config);
    const second_limit = try runChild(allocator, &limit_state, limit_model.model(), limit_config);
    var deep_model = try modelFor(allocator, "record", "limit");
    const deep_config = RunConfig{
        .allowed = &.{"record"},
        .policy = permissiveRecord,
        .policy_ctx = @ptrCast(&limit_state),
        .depth = 2,
        .max_depth = 1,
    };
    const deep = try runChild(allocator, &limit_state, deep_model.model(), deep_config);
    if (!std.mem.eql(u8, first_limit.status, "completed")) return error.LimitFirst;
    if (!std.mem.eql(u8, second_limit.@"error", "CHILD_LIMIT")) return error.LimitSecond;
    if (!std.mem.eql(u8, deep.@"error", "DEPTH_LIMIT")) return error.LimitDepth;
    if (effectCount(&limit_state, "limit") != 1) return error.LimitEffect;

    var cancel_state = GovState.init(allocator);
    var cancel_model = try modelFor(allocator, "record", "cancel");
    const cancelled = try runChild(allocator, &cancel_state, cancel_model.model(), .{
        .allowed = &.{"record"},
        .policy = permissiveRecord,
        .policy_ctx = @ptrCast(&cancel_state),
        .cancelled = true,
    });
    if (!std.mem.eql(u8, cancelled.status, "cancelled")) return error.CancelStatus;
    if (effectCount(&cancel_state, "cancel") != 0) return error.CancelEffect;

    var edit_state = GovState.init(allocator);
    var edit_model = try modelFor(allocator, "record", "edit-me");
    const edited = try runChild(allocator, &edit_state, edit_model.model(), .{
        .allowed = &.{"record"},
        .policy = parentBlocked,
        .policy_ctx = @ptrCast(&edit_state),
        .edit_to_blocked = true,
    });
    if (!std.mem.eql(u8, edited.status, "failed")) return error.EditStatus;
    if (effectCount(&edit_state, "edit-me") != 0) return error.EditEffect;
    if (effectCount(&edit_state, "blocked") != 0) return error.EditBlocked;

    std.debug.print("Zig advanced delegation governance: 6/6 passed\n", .{});
}
