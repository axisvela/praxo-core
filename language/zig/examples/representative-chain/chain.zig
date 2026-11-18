const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const models = praxo.models;
const json = praxo.json;
const mcp = praxo.mcp;
const runtime = praxo.runtime;
const otel = praxo.otel;
const harmovela = praxo.harmovela;

const Allocator = std.mem.Allocator;

const ChainState = struct {
    allocator: Allocator,
    effects: std.StringHashMap(i64),
    otel_events: std.array_list.Managed([]const u8),
    harmovela_events: std.array_list.Managed([]const u8),
    child_calls: i64 = 0,

    fn init(allocator: Allocator) ChainState {
        return .{
            .allocator = allocator,
            .effects = std.StringHashMap(i64).init(allocator),
            .otel_events = std.array_list.Managed([]const u8).init(allocator),
            .harmovela_events = std.array_list.Managed([]const u8).init(allocator),
        };
    }
};

fn fixedClock() otel.TimeParts {
    return .{ .seconds = 1794294000, .nanos = 0 };
}

fn fixedHarmovelaClock() harmovela.TimeParts {
    return .{ .seconds = 1794294000, .nanos = 0 };
}

fn bumpChildCalls(ctx: *anyopaque) void {
    const state: *ChainState = @ptrCast(@alignCast(ctx));
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

const RecordToolContext = struct {
    allocator: Allocator,
    client: *mcp.Client,
    state: *ChainState,
};

fn invokeRecord(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *RecordToolContext = @ptrCast(@alignCast(ctx));
    return self.client.callTool("record", arguments);
}

const DelegateToolContext = struct {
    allocator: Allocator,
    state: *ChainState,
    record: agent.Tool,
    events: runtime.EventSink,
};

fn childPolicy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return .{ .allowed = true };
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        return .{ .allowed = std.mem.eql(u8, name, "record") };
    }
    return .{ .allowed = false, .reason = "child may only record" };
}

fn invokeDelegate(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    _ = arguments;
    const self: *DelegateToolContext = @ptrCast(@alignCast(ctx));
    var child_steps = [_]models.Response{try toolResponse(self.allocator, try recordCall(self.allocator, "child-record", "child"))};
    var child_model = ScriptedModel.init(self.allocator, &child_steps, "DONE");
    child_model.on_call = bumpChildCalls;
    child_model.on_ctx = @ptrCast(self.state);
    var child_registry = agent.Registry.init(self.allocator);
    try child_registry.register(self.record);
    const allowed = [_][]const u8{"record"};
    const options = agent.AgentOptions{
        .model = child_model.model(),
        .tools = &child_registry,
        .max_steps = 3,
        .allowed_tools = &allowed,
        .policy = childPolicy,
        .policy_ctx = @ptrCast(self.state),
        .require_policy = true,
        .require_tool_scope = true,
        .events = self.events,
    };
    const result = try agent.runAgent(self.allocator, options, .{ .id = "chain-child" }, "record child");
    var output = std.json.ObjectMap.empty;
    try output.put(self.allocator, "output", .{ .string = result.output });
    return .{ .object = output };
}

fn parentPolicy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) return .{ .allowed = true };
    if (!std.mem.eql(u8, action.kind, "tool.invoke")) {
        return .{ .allowed = false, .reason = "unsupported action" };
    }
    const name = action.tool_name orelse return .{ .allowed = false };
    if (std.mem.eql(u8, name, "record")) {
        const target = if (action.arguments) |value|
            json.string(value, "target") orelse ""
        else
            "";
        if (std.mem.eql(u8, target, "blocked")) {
            return .{ .allowed = false, .reason = "blocked target" };
        }
        return .{ .allowed = true };
    }
    if (std.mem.eql(u8, name, "delegate")) return .{ .allowed = true };
    return .{ .allowed = false, .reason = "parent tool is not allowed" };
}

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

const McpContext = struct {
    allocator: Allocator,
    state: *ChainState,
};

fn mcpRequest(ctx: *anyopaque, allocator: Allocator, method: []const u8, params: json.Json, timeout: u64) !json.Json {
    _ = timeout;
    const state: *ChainState = @ptrCast(@alignCast(ctx));
    if (std.mem.eql(u8, method, "initialize")) {
        return json.parse(allocator, "{\"protocolVersion\":\"2024-11-05\",\"serverInfo\":{\"name\":\"fake-mcp\"}}");
    }
    if (std.mem.eql(u8, method, "tools/list")) {
        return json.parse(allocator, "{\"tools\":[{\"name\":\"record\",\"description\":\"Record a target\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"target\":{\"type\":\"string\"}},\"required\":[\"target\"]}}]}");
    }
    if (std.mem.eql(u8, method, "tools/call")) {
        const value = json.get(params, "arguments") orelse json.Json{ .null = {} };
        const text = json.string(value, "target") orelse "";
        state.effects.put(text, (state.effects.get(text) orelse 0) + 1) catch {};
        var content = std.json.Array.init(allocator);
        var item = std.json.ObjectMap.empty;
        try item.put(allocator, "type", .{ .string = "text" });
        try item.put(allocator, "text", .{ .string = try std.fmt.allocPrint(allocator, "recorded:{s}", .{text}) });
        try content.append(.{ .object = item });
        var result = std.json.ObjectMap.empty;
        try result.put(allocator, "content", .{ .array = content });
        return .{ .object = result };
    }
    return json.parse(allocator, "{}");
}

fn mcpNotify(_: *anyopaque, _: Allocator, _: []const u8, _: json.Json) !void {}
fn mcpClose(_: *anyopaque) void {}

fn otelSend(ctx: *anyopaque, allocator: Allocator, request: otel.HttpRequest) !otel.TransportResult {
    const state: *ChainState = @ptrCast(@alignCast(ctx));
    const payload = json.parse(allocator, request.body) catch json.Json{ .null = {} };
    for (json.array(payload, "resourceSpans")) |resource| {
        for (json.array(resource, "scopeSpans")) |scope_value| {
            for (json.array(scope_value, "spans")) |span| {
                state.otel_events.append(json.string(span, "name") orelse "") catch {};
            }
        }
    }
    return .{ .status = 200, .body = "" };
}

fn harmovelaSend(ctx: *anyopaque, allocator: Allocator, request: harmovela.HttpRequest) !harmovela.TransportResult {
    const state: *ChainState = @ptrCast(@alignCast(ctx));
    const payload = json.parse(allocator, request.body) catch json.Json{ .null = {} };
    state.harmovela_events.append(json.string(payload, "type") orelse "") catch {};
    return .{ .status = 202, .body = "" };
}

fn interruptDecide(_: *anyopaque, interrupt: agent.Interrupt) agent.InterruptDecision {
    _ = interrupt;
    var arguments = std.json.ObjectMap.empty;
    arguments.put(std.heap.page_allocator, "target", .{ .string = "blocked" }) catch unreachable;
    return .{ .action = agent.INTERRUPT_EDIT, .arguments = .{ .object = arguments } };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state = ChainState.init(allocator);

    const transport = mcp.Transport{
        .ctx = @ptrCast(&state),
        .requestFn = mcpRequest,
        .notifyFn = mcpNotify,
        .closeFn = mcpClose,
    };
    var client = mcp.Client.init(allocator, transport, "2024-11-05", "0.0.0", 1000);
    try client.start();
    const tools = try client.listTools();
    if (tools.len != 1) return error.UnexpectedTools;

    var record_ctx = RecordToolContext{ .allocator = allocator, .client = &client, .state = &state };
    const record = agent.Tool{
        .ctx = @ptrCast(&record_ctx),
        .name = "record",
        .description = "Record a target through the MCP client",
        .invokeFn = invokeRecord,
    };

    var otel_sink = otel.Sink.init(allocator, "http://otel.local/v1/traces");
    otel_sink.transport = .{ .ctx = @ptrCast(&state), .sendFn = otelSend };
    otel_sink.clock = fixedClock;
    var harmovela_sink = harmovela.Sink.init(allocator, "http://harmovela.local");
    harmovela_sink.transport = .{ .ctx = @ptrCast(&state), .sendFn = harmovelaSend };
    harmovela_sink.clock = fixedHarmovelaClock;
    var sinks = [_]runtime.EventSink{ otel_sink.eventSink(), harmovela_sink.eventSink() };
    var multi = runtime.MultiSink.init(&sinks);
    const events = multi.sink();

    var delegate_ctx = DelegateToolContext{
        .allocator = allocator,
        .state = &state,
        .record = record,
        .events = events,
    };
    const delegate = agent.Tool{
        .ctx = @ptrCast(&delegate_ctx),
        .name = "delegate",
        .description = "Run a governed child agent with the narrowed record scope",
        .invokeFn = invokeDelegate,
    };

    var parent_steps = [_]models.Response{
        try toolResponse(allocator, try recordCall(allocator, "parent-record", "parent")),
        try toolResponse(allocator, try delegateCall(allocator, "parent-delegate")),
    };
    var parent_model = ScriptedModel.init(allocator, &parent_steps, "DONE");
    var registry = agent.Registry.init(allocator);
    try registry.register(record);
    try registry.register(delegate);
    const parent_allowed = [_][]const u8{ "record", "delegate" };
    const parent_options = agent.AgentOptions{
        .model = parent_model.model(),
        .tools = &registry,
        .max_steps = 4,
        .allowed_tools = &parent_allowed,
        .policy = parentPolicy,
        .policy_ctx = @ptrCast(&state),
        .require_policy = true,
        .require_tool_scope = true,
        .events = events,
    };
    const parent = try agent.runAgent(allocator, parent_options, .{ .id = "chain-parent" }, "record parent, then delegate");

    var denied_steps = [_]models.Response{try toolResponse(allocator, try recordCall(allocator, "denied-record", "edit-me"))};
    var denied_model = ScriptedModel.init(allocator, &denied_steps, "DONE");
    var denied_registry = agent.Registry.init(allocator);
    try denied_registry.register(record);
    const denied_allowed = [_][]const u8{"record"};
    const denied_interrupt = [_][]const u8{"record"};
    const denied_options = agent.AgentOptions{
        .model = denied_model.model(),
        .tools = &denied_registry,
        .max_steps = 2,
        .allowed_tools = &denied_allowed,
        .policy = parentPolicy,
        .policy_ctx = @ptrCast(&state),
        .require_policy = true,
        .require_tool_scope = true,
        .interrupt_on = &denied_interrupt,
        .on_interrupt_decision = .{ .ctx = @ptrCast(&state), .decideFn = interruptDecide },
        .events = events,
    };
    var denied_error = false;
    _ = agent.runAgent(allocator, denied_options, .{ .id = "chain-denied" }, "attempt a denied edit") catch {
        denied_error = true;
    };

    client.close();
    std.debug.print("output: {s}\n", .{parent.output});
    std.debug.print("effects: parent={d} child={d}\n", .{ state.effects.get("parent") orelse 0, state.effects.get("child") orelse 0 });
    std.debug.print("child calls: {d}\n", .{state.child_calls});
    std.debug.print("otel spans: {d}\n", .{state.otel_events.items.len});
    std.debug.print("harmovela events: {d}\n", .{state.harmovela_events.items.len});
    std.debug.print("denied effects: {d}\n", .{state.effects.get("blocked") orelse 0});
    if (!std.mem.eql(u8, parent.output, "DONE")) return error.ChainFailed;
    if ((state.effects.get("parent") orelse 0) != 1) return error.ChainFailed;
    if ((state.effects.get("child") orelse 0) != 1) return error.ChainFailed;
    if (state.child_calls != 2) return error.ChainFailed;
    if (state.otel_events.items.len < 3) return error.ChainFailed;
    if (state.harmovela_events.items.len < 3) return error.ChainFailed;
    if ((state.effects.get("blocked") orelse 0) != 0) return error.ChainFailed;
    if (!denied_error) return error.ChainFailed;
}
