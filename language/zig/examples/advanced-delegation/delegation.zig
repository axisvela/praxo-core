const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const models = praxo.models;
const json = praxo.json;

const Allocator = std.mem.Allocator;

const DemoState = struct {
    allocator: Allocator,
    effects: std.StringHashMap(i64),
    child_calls: i64 = 0,

    fn init(allocator: Allocator) DemoState {
        return .{ .allocator = allocator, .effects = std.StringHashMap(i64).init(allocator) };
    }
};

fn bumpChild(ctx: *anyopaque) void {
    const state: *DemoState = @ptrCast(@alignCast(ctx));
    state.child_calls += 1;
}

const ScriptedModel = struct {
    allocator: Allocator,
    steps: std.array_list.Managed(models.Response),
    final_content: []const u8,
    on_call: ?*const fn (*anyopaque) void = null,
    on_ctx: ?*anyopaque = null,

    fn init(allocator: Allocator, steps: []const models.Response, final_content: []const u8) ScriptedModel {
        var list = std.array_list.Managed(models.Response).init(allocator);
        list.appendSlice(steps) catch unreachable;
        return .{ .allocator = allocator, .steps = list, .final_content = final_content };
    }

    fn model(self: *ScriptedModel) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = request;
        const self: *ScriptedModel = @ptrCast(@alignCast(ctx));
        if (self.on_call) |callback| callback(self.on_ctx.?);
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

fn recordCall(allocator: Allocator, id: []const u8, target: []const u8) !models.ToolCall {
    var arguments = std.json.ObjectMap.empty;
    try arguments.put(allocator, "target", .{ .string = target });
    return .{ .id = id, .name = "record", .arguments = .{ .object = arguments } };
}

fn delegateCall(allocator: Allocator, id: []const u8) !models.ToolCall {
    var arguments = std.json.ObjectMap.empty;
    try arguments.put(allocator, "task", .{ .string = "record child" });
    return .{ .id = id, .name = "delegate", .arguments = .{ .object = arguments } };
}

const RecordContext = struct {
    state: *DemoState,
};

fn invokeRecord(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *RecordContext = @ptrCast(@alignCast(ctx));
    const target = json.string(arguments, "target") orelse "";
    self.state.effects.put(target, (self.state.effects.get(target) orelse 0) + 1) catch {};
    return .{ .string = "recorded" };
}

const DelegateContext = struct {
    allocator: Allocator,
    state: *DemoState,
    record: agent.Tool,
};

fn childPolicy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return .{ .allowed = true };
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        return .{ .allowed = std.mem.eql(u8, name, "record") };
    }
    return .{ .allowed = false };
}

fn parentPolicy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return .{ .allowed = true };
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        return .{ .allowed = std.mem.eql(u8, name, "delegate") };
    }
    return .{ .allowed = false };
}

fn invokeDelegate(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    _ = arguments;
    const self: *DelegateContext = @ptrCast(@alignCast(ctx));
    var child_steps = [_]models.Response{try toolResponse(self.allocator, try recordCall(self.allocator, "child-record", "child"))};
    var child_model = ScriptedModel.init(self.allocator, &child_steps, "child done");
    child_model.on_call = bumpChild;
    child_model.on_ctx = @ptrCast(self.state);
    var registry = agent.Registry.init(self.allocator);
    try registry.register(self.record);
    const allowed = [_][]const u8{"record"};
    const options = agent.AgentOptions{
        .model = child_model.model(),
        .tools = &registry,
        .max_steps = 3,
        .allowed_tools = &allowed,
        .policy = childPolicy,
        .policy_ctx = @ptrCast(self.state),
        .require_policy = true,
        .require_tool_scope = true,
    };
    const result = try agent.runAgent(self.allocator, options, .{ .id = "demo-child" }, "record child");
    return .{ .string = result.output };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var state = DemoState.init(allocator);

    var record_context = RecordContext{ .state = &state };
    const record = agent.Tool{
        .ctx = @ptrCast(&record_context),
        .name = "record",
        .description = "Record a target in an in-memory counter",
        .invokeFn = invokeRecord,
    };
    var delegate_context = DelegateContext{ .allocator = allocator, .state = &state, .record = record };
    const delegate = agent.Tool{
        .ctx = @ptrCast(&delegate_context),
        .name = "delegate",
        .description = "Run a child agent with a narrowed record scope",
        .invokeFn = invokeDelegate,
    };

    var parent_steps = [_]models.Response{try toolResponse(allocator, try delegateCall(allocator, "parent-delegate"))};
    var parent_model = ScriptedModel.init(allocator, &parent_steps, "parent done");
    var registry = agent.Registry.init(allocator);
    try registry.register(record);
    try registry.register(delegate);
    const allowed = [_][]const u8{"delegate"};
    const options = agent.AgentOptions{
        .model = parent_model.model(),
        .tools = &registry,
        .max_steps = 3,
        .allowed_tools = &allowed,
        .policy = parentPolicy,
        .policy_ctx = @ptrCast(&state),
        .require_policy = true,
        .require_tool_scope = true,
    };
    const result = try agent.runAgent(allocator, options, .{ .id = "demo-parent" }, "delegate");
    std.debug.print("delegation: child recorded; parent scope enforced\n", .{});

    var direct_registry = agent.Registry.init(allocator);
    try direct_registry.register(record);
    var direct_steps = [_]models.Response{try toolResponse(allocator, try recordCall(allocator, "direct-record", "child"))};
    var direct_model = ScriptedModel.init(allocator, &direct_steps, "parent done");
    const direct_options = agent.AgentOptions{
        .model = direct_model.model(),
        .tools = &direct_registry,
        .max_steps = 2,
        .allowed_tools = &allowed,
        .policy = parentPolicy,
        .policy_ctx = @ptrCast(&state),
        .require_policy = true,
        .require_tool_scope = true,
    };
    var denied = false;
    _ = agent.runAgent(allocator, direct_options, .{ .id = "demo-direct" }, "record directly") catch {
        denied = true;
    };
    std.debug.print("deny: parent record blocked; child effect unchanged\n", .{});
    if (!std.mem.eql(u8, result.output, "parent done")) return error.DelegationFailed;
    if ((state.effects.get("child") orelse 0) != 1) return error.DelegationFailed;
    if (!denied) return error.DelegationFailed;
}
