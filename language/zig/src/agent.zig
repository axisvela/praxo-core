const std = @import("std");
const ids = @import("ids.zig");
const json = @import("json.zig");
const models = @import("models.zig");
const runtime = @import("runtime.zig");

const Allocator = std.mem.Allocator;

pub const DeltaHandler = struct {
    ctx: *anyopaque,
    emitFn: *const fn (ctx: *anyopaque, delta: []const u8) void,

    pub fn emit(self: DeltaHandler, delta: []const u8) void {
        self.emitFn(self.ctx, delta);
    }
};

pub const Model = struct {
    ctx: *anyopaque,
    generateFn: *const fn (ctx: *anyopaque, request: models.Request) anyerror!models.Response,
    streamFn: ?*const fn (ctx: *anyopaque, request: models.Request, on_delta: DeltaHandler) anyerror!models.Response = null,

    pub fn generate(self: Model, request: models.Request) !models.Response {
        return self.generateFn(self.ctx, request);
    }

    pub fn generateStream(self: Model, request: models.Request, on_delta: DeltaHandler) !models.Response {
        if (self.streamFn) |stream_fn| {
            return stream_fn(self.ctx, request, on_delta);
        }
        const response = try self.generate(request);
        if (response.message.content) |content| {
            if (content.len > 0) on_delta.emit(content);
        }
        return response;
    }
};

pub const Tool = struct {
    ctx: *anyopaque,
    name: []const u8,
    description: []const u8,
    invokeFn: *const fn (ctx: *anyopaque, arguments: json.Json) anyerror!json.Json,

    pub fn invoke(self: Tool, arguments: json.Json) !json.Json {
        return self.invokeFn(self.ctx, arguments);
    }
};

pub const Registry = struct {
    allocator: Allocator,
    tools: std.StringHashMap(Tool),

    pub fn init(allocator: Allocator) Registry {
        return .{ .allocator = allocator, .tools = std.StringHashMap(Tool).init(allocator) };
    }

    pub fn register(self: *Registry, tool: Tool) !void {
        try self.tools.put(tool.name, tool);
    }

    pub fn get(self: *Registry, name: []const u8) !Tool {
        return self.tools.get(name) orelse error.ToolNotFound;
    }

    pub fn specs(self: *Registry, allocator: Allocator) ![]models.ToolSpec {
        var out = std.array_list.Managed(models.ToolSpec).init(allocator);
        var iterator = self.tools.valueIterator();
        while (iterator.next()) |tool| {
            try out.append(.{ .name = tool.name, .description = tool.description });
        }
        std.mem.sort(models.ToolSpec, out.items, {}, lessByName);
        return out.toOwnedSlice();
    }
};

fn lessByName(_: void, left: models.ToolSpec, right: models.ToolSpec) bool {
    return std.mem.order(u8, left.name, right.name) == .lt;
}

pub const StaticModel = struct {
    content: []const u8,

    pub fn model(self: *StaticModel) Model {
        return .{ .ctx = self, .generateFn = generateFn };
    }

    fn generateFn(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = request;
        const self: *StaticModel = @ptrCast(@alignCast(ctx));
        return .{ .message = .{ .role = models.ASSISTANT, .content = self.content } };
    }
};

pub const PolicyFn = *const fn (ctx: *anyopaque, action: models.Action) models.Decision;

pub const INTERRUPT_APPROVE = "approve";
pub const INTERRUPT_EDIT = "edit";
pub const INTERRUPT_REJECT = "reject";
pub const INTERRUPT_RESPOND = "respond";

pub const Interrupt = struct {
    run_id: []const u8,
    session_id: []const u8,
    call: models.ToolCall,
};

pub const InterruptDecision = struct {
    action: []const u8,
    arguments: ?json.Json = null,
    response: []const u8 = "",
    reason: []const u8 = "",
};

pub const InterruptHandler = struct {
    ctx: *anyopaque,
    decideFn: *const fn (ctx: *anyopaque, interrupt: Interrupt) InterruptDecision,

    pub fn decide(self: InterruptHandler, interrupt: Interrupt) InterruptDecision {
        return self.decideFn(self.ctx, interrupt);
    }
};

pub const InterruptApproval = struct {
    ctx: *anyopaque,
    approveFn: *const fn (ctx: *anyopaque, interrupt: Interrupt) bool,

    pub fn approve(self: InterruptApproval, interrupt: Interrupt) bool {
        return self.approveFn(self.ctx, interrupt);
    }
};

pub const AgentOptions = struct {
    model: Model,
    tools: ?*Registry = null,
    events: ?runtime.EventSink = null,
    policy: ?PolicyFn = null,
    policy_ctx: ?*anyopaque = null,
    system_prompt: []const u8 = "",
    context: ?runtime.ContextBudget = null,
    max_steps: i64 = 8,
    max_tokens: i64 = 0,
    allowed_tools: []const []const u8 = &.{},
    interrupt_on: []const []const u8 = &.{},
    on_interrupt_decision: ?InterruptHandler = null,
    on_interrupt: ?InterruptApproval = null,
    on_delta: ?DeltaHandler = null,
    require_policy: bool = false,
    require_tool_scope: bool = false,
};

pub const AgentError = error{
    AgentInvalidOptions,
    AgentMaxSteps,
    AgentMaxTokens,
    AgentContextBudget,
    AgentToolNotAllowed,
    AgentInterruptUnhandled,
    AgentApprovalDenied,
    AgentInterruptDecisionInvalid,
    ToolNotFound,
    PolicyError,
};

pub const Agent = struct {
    options: AgentOptions,

    pub fn init(options: AgentOptions) Agent {
        return .{ .options = options };
    }

    pub fn run(self: *Agent, allocator: Allocator, session: models.Session, prompt: []const u8) !models.RunResult {
        const options = self.options;
        if (options.require_policy and options.policy == null) {
            return AgentError.AgentInvalidOptions;
        }
        if (options.require_tool_scope and options.allowed_tools.len == 0) {
            return AgentError.AgentInvalidOptions;
        }
        const max_steps: i64 = if (options.max_steps > 0) options.max_steps else 8;
        const run_id = try std.fmt.allocPrint(allocator, "run-{d}", .{ids.next()});
        var messages = std.array_list.Managed(models.Message).init(allocator);
        for (session.messages) |message| try messages.append(message);
        if (options.system_prompt.len > 0) {
            try messages.insert(0, .{ .role = models.SYSTEM, .content = options.system_prompt });
        }
        try messages.append(.{ .role = models.USER, .content = prompt });
        var usage = models.Usage{};
        self.emit(.{ .type = "run.started", .session_id = session.id, .run_id = run_id });
        var step: i64 = 0;
        while (step < max_steps) : (step += 1) {
            self.authorize(.{ .kind = "model.generate", .session_id = session.id }) catch |error_value| {
                self.emitFailure(session.id, run_id, error_value);
                return error_value;
            };
            if (options.context) |budget| {
                const compacted = runtime.compact(allocator, budget, messages.items) catch |error_value| {
                    self.emitFailure(session.id, run_id, error_value);
                    return AgentError.AgentContextBudget;
                };
                if (!compacted.ok) {
                    self.emitFailure(session.id, run_id, AgentError.AgentContextBudget);
                    return AgentError.AgentContextBudget;
                }
                messages.clearRetainingCapacity();
                for (compacted.messages) |message| try messages.append(message);
            }
            const request = models.Request{
                .messages = messages.items,
                .tools = try self.advertisedTools(allocator),
            };
            const response = if (options.on_delta) |on_delta|
                options.model.generateStream(request, on_delta) catch |error_value| {
                    self.emitFailure(session.id, run_id, error_value);
                    return error_value;
                }
            else
                options.model.generate(request) catch |error_value| {
                    self.emitFailure(session.id, run_id, error_value);
                    return error_value;
                };
            usage = models.usagePlus(usage, response.usage);
            if (options.max_tokens > 0 and usage.input_tokens + usage.output_tokens > options.max_tokens) {
                self.emitFailure(session.id, run_id, AgentError.AgentMaxTokens);
                return AgentError.AgentMaxTokens;
            }
            try messages.append(response.message);
            if (response.message.tool_calls.len == 0) {
                self.emit(.{ .type = "run.completed", .session_id = session.id, .run_id = run_id });
                return .{
                    .run_id = run_id,
                    .output = response.message.content orelse "",
                    .steps = step + 1,
                    .usage = usage,
                };
            }
            for (response.message.tool_calls) |call| {
                const message = self.invokeTool(allocator, call, run_id, session.id) catch |error_value| {
                    self.emitFailure(session.id, run_id, error_value);
                    return error_value;
                };
                try messages.append(message);
            }
        }
        self.emitFailure(session.id, run_id, AgentError.AgentMaxSteps);
        return AgentError.AgentMaxSteps;
    }

    fn invokeTool(self: *Agent, allocator: Allocator, call: models.ToolCall, run_id: []const u8, session_id: []const u8) !models.Message {
        if (!self.allowed(call.name)) return AgentError.AgentToolNotAllowed;
        try self.authorize(.{ .kind = "tool.invoke", .session_id = session_id, .tool_name = call.name, .arguments = call.arguments });
        const registry = self.options.tools orelse return AgentError.ToolNotFound;
        var active = call;
        const original_arguments = call.arguments;
        if (try self.applyInterrupt(allocator, &active, run_id, session_id)) |response| {
            return .{
                .role = models.TOOL,
                .content = try json.stringify(allocator, .{ .string = response }),
                .tool_id = active.id,
            };
        }
        if (!self.allowed(active.name)) return AgentError.AgentToolNotAllowed;
        if (!std.mem.eql(u8, active.name, call.name) or !json.equals(active.arguments, original_arguments)) {
            try self.authorize(.{ .kind = "tool.invoke", .session_id = session_id, .tool_name = active.name, .arguments = active.arguments });
        }
        const tool = registry.get(active.name) catch return AgentError.ToolNotFound;
        var data = std.json.ObjectMap.empty;
        try data.put(allocator, "name", .{ .string = active.name });
        try data.put(allocator, "arguments", active.arguments);
        self.emit(.{ .type = "tool.call", .session_id = session_id, .run_id = run_id, .data = .{ .object = data } });
        const value = tool.invoke(active.arguments) catch |error_value| {
            self.emitFailure(session_id, run_id, error_value);
            return error_value;
        };
        return .{
            .role = models.TOOL,
            .content = try json.stringify(allocator, value),
            .tool_id = active.id,
        };
    }

    fn applyInterrupt(self: *Agent, allocator: Allocator, call: *models.ToolCall, run_id: []const u8, session_id: []const u8) !?[]const u8 {
        if (!self.interruptOn(call.name)) return null;
        if (self.options.on_interrupt_decision == null and self.options.on_interrupt == null) {
            return AgentError.AgentInterruptUnhandled;
        }
        var data = std.json.ObjectMap.empty;
        try data.put(allocator, "name", .{ .string = call.name });
        try data.put(allocator, "arguments", call.arguments);
        self.emit(.{ .type = "tool.interrupt", .session_id = session_id, .run_id = run_id, .data = .{ .object = data } });
        const interrupt = Interrupt{ .run_id = run_id, .session_id = session_id, .call = call.* };
        if (self.options.on_interrupt_decision) |handler| {
            const decision = handler.decide(interrupt);
            if (std.mem.eql(u8, decision.action, INTERRUPT_APPROVE)) return null;
            if (std.mem.eql(u8, decision.action, INTERRUPT_EDIT)) {
                const arguments = decision.arguments orelse return AgentError.AgentInterruptDecisionInvalid;
                call.arguments = arguments;
                return null;
            }
            if (std.mem.eql(u8, decision.action, INTERRUPT_REJECT)) return AgentError.AgentApprovalDenied;
            if (std.mem.eql(u8, decision.action, INTERRUPT_RESPOND)) return decision.response;
            return AgentError.AgentInterruptDecisionInvalid;
        }
        if (self.options.on_interrupt) |approval| {
            if (!approval.approve(interrupt)) return AgentError.AgentApprovalDenied;
            return null;
        }
        return AgentError.AgentInterruptUnhandled;
    }

    fn interruptOn(self: *Agent, name: []const u8) bool {
        for (self.options.interrupt_on) |item| {
            if (std.mem.eql(u8, item, name)) return true;
        }
        return false;
    }

    fn advertisedTools(self: *Agent, allocator: Allocator) ![]models.ToolSpec {
        const registry = self.options.tools orelse return &.{};
        const specs = try registry.specs(allocator);
        if (self.options.allowed_tools.len == 0) return specs;
        var filtered = std.array_list.Managed(models.ToolSpec).init(allocator);
        for (specs) |spec| {
            if (self.allowed(spec.name)) try filtered.append(spec);
        }
        return filtered.toOwnedSlice();
    }

    fn allowed(self: *Agent, name: []const u8) bool {
        if (self.options.allowed_tools.len == 0) return true;
        for (self.options.allowed_tools) |item| {
            if (std.mem.eql(u8, item, name)) return true;
        }
        return false;
    }

    fn authorize(self: *Agent, action: models.Action) !void {
        const policy = self.options.policy orelse return;
        const ctx = self.options.policy_ctx orelse return AgentError.PolicyError;
        const decision = policy(ctx, action);
        if (!decision.allowed) return AgentError.PolicyError;
    }

    fn emit(self: *Agent, event: models.Event) void {
        if (self.options.events) |sink| sink.emit(event);
    }

    fn emitFailure(self: *Agent, session_id: []const u8, run_id: []const u8, error_value: anyerror) void {
        _ = @errorName(error_value);
        self.emit(.{ .type = "run.failed", .session_id = session_id, .run_id = run_id });
    }
};

pub fn runAgent(allocator: Allocator, options: AgentOptions, session: models.Session, prompt: []const u8) !models.RunResult {
    var agent = Agent.init(options);
    return agent.run(allocator, session, prompt);
}
