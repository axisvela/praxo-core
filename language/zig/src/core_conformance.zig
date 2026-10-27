const std = @import("std");
const agent = @import("agent.zig");
const ids = @import("ids.zig");
const json = @import("json.zig");
const middleware = @import("middleware.zig");
const models = @import("models.zig");
const runtime = @import("runtime.zig");

const Allocator = std.mem.Allocator;
const CheckError = error{CheckFailed};

fn check(condition: bool) !void {
    if (!condition) return CheckError.CheckFailed;
}

pub fn errorCode(error_value: anyerror) []const u8 {
    return switch (error_value) {
        error.AgentMaxSteps => "AGENT_MAX_STEPS",
        error.AgentMaxTokens => "AGENT_MAX_TOKENS",
        error.AgentContextBudget => "AGENT_CONTEXT_BUDGET",
        error.ToolNotFound => "TOOL_NOT_FOUND",
        error.PolicyError => "POLICY_ERROR",
        error.AgentModelCallLimit => "AGENT_MODEL_CALL_LIMIT",
        error.AgentToolCallLimit => "AGENT_TOOL_CALL_LIMIT",
        error.AgentToolNotSelected => "AGENT_TOOL_NOT_SELECTED",
        error.CheckpointTypeNotAllowed => "CHECKPOINT_TYPE_NOT_ALLOWED",
        error.CheckpointError => "CHECKPOINT_ERROR",
        else => "",
    };
}

const RecordingSink = struct {
    types: std.array_list.Managed([]const u8),

    fn init(allocator: Allocator) RecordingSink {
        return .{ .types = std.array_list.Managed([]const u8).init(allocator) };
    }

    fn sink(self: *RecordingSink) runtime.EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ctx: *anyopaque, event: models.Event) void {
        const self: *RecordingSink = @ptrCast(@alignCast(ctx));
        self.types.append(event.type) catch {};
    }
};

fn runMemory(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    var store = runtime.MemoryStore.init(allocator);
    for (json.array(input, "puts")) |put| {
        const record = json.get(put, "record") orelse json.Json{ .object = .empty };
        _ = try store.put(
            json.string(put, "session") orelse "",
            .{
                .id = json.string(record, "id") orelse "",
                .frame = json.string(record, "frame") orelse "",
                .content = json.string(record, "content") orelse "",
                .created_at = json.string(record, "createdAt"),
            },
        );
    }
    const records = try store.search(
        allocator,
        json.string(input, "session") orelse "",
        json.string(input, "query") orelse "",
        @intCast(json.integer(input, "limit", 0)),
    );
    const expected_ids = json.get(expect, "ids");
    const expected_contents = json.get(expect, "contents");
    if (expected_ids == null or expected_ids.? == .null) {
        try check(records.len == 0);
        return;
    }
    try check(records.len == expected_ids.?.array.items.len);
    for (records, 0..) |record, index| {
        try check(std.mem.eql(u8, record.id, expected_ids.?.array.items[index].string));
        if (expected_contents) |contents| {
            try check(std.mem.eql(u8, record.content, contents.array.items[index].string));
        }
    }
}

const Predicate = struct {
    allowed: ?[]const []const u8 = null,

    fn matches(ctx: *anyopaque, event: models.Event) bool {
        const self: *Predicate = @ptrCast(@alignCast(ctx));
        if (self.allowed) |allowed| {
            for (allowed) |candidate| {
                if (std.mem.eql(u8, candidate, event.type)) return true;
            }
            return false;
        }
        return true;
    }
};

fn runEvent(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    var events = std.array_list.Managed(models.Event).init(allocator);
    for (json.array(input, "events")) |item| {
        try events.append(.{ .type = item.string, .session_id = "s1" });
    }
    if (std.mem.eql(u8, json.string(input, "sink") orelse "filter", "multi")) {
        const count: usize = @intCast(@max(1, json.integer(input, "sinkCount", 1)));
        const sinks = try allocator.alloc(RecordingSink, count);
        var sink_values = std.array_list.Managed(runtime.EventSink).init(allocator);
        for (sinks) |*sink| {
            sink.* = RecordingSink.init(allocator);
            try sink_values.append(sink.sink());
        }
        var multi = runtime.MultiSink.init(sink_values.items);
        for (events.items) |event| multi.sink().emit(event);
        var per_sink = std.json.Array.init(allocator);
        for (sinks) |sink| {
            var types = std.json.Array.init(allocator);
            for (sink.types.items) |kind| try types.append(.{ .string = kind });
            try per_sink.append(.{ .array = types });
        }
        try check(json.equals(.{ .array = per_sink }, json.get(expect, "perSink") orelse json.Json{ .null = {} }));
        return;
    }
    var sink = RecordingSink.init(allocator);
    var predicate = Predicate{};
    if (json.get(input, "predicateTypes")) |types| {
        if (types == .array) {
            var allowed = std.array_list.Managed([]const u8).init(allocator);
            for (types.array.items) |item| try allowed.append(item.string);
            predicate.allowed = allowed.items;
        }
    }
    var filter = runtime.FilterSink.init(sink.sink(), &predicate, Predicate.matches);
    for (events.items) |event| filter.sink().emit(event);
    var delivered = std.json.Array.init(allocator);
    for (sink.types.items) |kind| try delivered.append(.{ .string = kind });
    const expected = json.get(expect, "delivered") orelse json.Json{ .null = {} };
    if (sink.types.items.len == 0) {
        try check(expected == .null);
    } else {
        try check(json.equals(.{ .array = delivered }, expected));
    }
}

fn runStream(allocator: Allocator, expect: json.Json) !void {
    var kinds = std.json.Array.init(allocator);
    for (models.stream_kinds) |kind| try kinds.append(.{ .string = kind });
    try check(json.equals(.{ .array = kinds }, json.get(expect, "kinds") orelse json.Json{ .null = {} }));
}

fn runCheckpoint(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    var allowlist = runtime.CheckpointAllowlist.init(allocator);
    for (json.array(input, "registered")) |item| try allowlist.register(item.string);
    const operation = json.string(input, "operation") orelse "roundtrip";
    const payload_type = json.string(input, "type") orelse "";
    const value = json.get(input, "value") orelse json.Json{ .null = {} };
    if (std.mem.eql(u8, operation, "roundtrip")) {
        const data = try allowlist.marshal(payload_type, value);
        try check(json.equals(try allowlist.unmarshal(data), json.get(expect, "value") orelse json.Json{ .null = {} }));
        return;
    }
    var caught: ?anyerror = null;
    if (std.mem.eql(u8, operation, "marshal")) {
        _ = allowlist.marshal(payload_type, value) catch |error_value| {
            caught = error_value;
        };
    } else if (std.mem.eql(u8, operation, "unmarshal")) {
        var envelope = std.json.ObjectMap.empty;
        try envelope.put(allocator, "type", .{ .string = payload_type });
        try envelope.put(allocator, "data", value);
        const encoded = try json.stringify(allocator, .{ .object = envelope });
        _ = allowlist.unmarshal(encoded) catch |error_value| {
            caught = error_value;
        };
    } else {
        caught = error.CheckpointError;
    }
    if (caught) |error_value| {
        try check(std.mem.eql(u8, errorCode(error_value), json.string(expect, "errorCode") orelse ""));
    } else {
        try check(json.get(expect, "errorCode") == null);
    }
}

fn runPolicy(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    const root = try std.fmt.allocPrint(allocator, "praxo-policy-{d}", .{ids.next()});
    var grants = std.array_list.Managed(models.PathGrant).init(allocator);
    for (json.array(input, "grants")) |item| {
        const grant_root = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, json.string(item, "root") orelse "" });
        try grants.append(.{ .root = grant_root, .access = json.string(item, "access") orelse "read" });
    }
    var checker = try runtime.PathChecker.init(allocator, grants.items);
    const target = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, json.string(input, "target") orelse "" });
    const need = json.string(input, "need") orelse "read";
    if (json.boolean(expect, "error", false)) {
        _ = checker.check(target, need) catch |error_value| {
            try check(error_value == error.PolicyError);
            return;
        };
        return error.CheckFailed;
    }
    const decision = try checker.check(target, need);
    try check(decision.allowed == json.boolean(expect, "allowed", false));
}

fn runContext(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    var messages = std.array_list.Managed(models.Message).init(allocator);
    for (json.array(input, "messages")) |item| {
        try messages.append(.{
            .role = json.string(item, "role") orelse "",
            .content = json.string(item, "content"),
        });
    }
    if (std.mem.eql(u8, json.string(input, "operation") orelse "", "estimate")) {
        try check(runtime.estimateTokens(messages.items) == json.integer(expect, "tokens", 0));
        return;
    }
    const budget_json = json.get(input, "budget") orelse json.Json{ .object = .empty };
    const budget = runtime.ContextBudget{
        .max_tokens = json.integer(budget_json, "maxTokens", 0),
        .keep_recent = json.integer(budget_json, "keepRecent", 0),
    };
    const result = try runtime.compact(allocator, budget, messages.items);
    try check(result.ok == json.boolean(expect, "ok", false));
    if (!result.ok) return;
    try check(runtime.estimateTokens(result.messages) == json.integer(expect, "tokens", 0));
    var wires = std.json.Array.init(allocator);
    for (result.messages) |message| try wires.append(try models.messageWire(allocator, message));
    try check(json.equals(.{ .array = wires }, json.get(expect, "messages") orelse json.Json{ .null = {} }));
}

const RepairContext = struct {
    output: []const u8,

    fn repair(ctx: ?*anyopaque, text: []const u8) ?[]const u8 {
        _ = text;
        const self: *RepairContext = @ptrCast(@alignCast(ctx.?));
        return self.output;
    }
};

fn runMiddleware(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    const operation = json.string(input, "operation") orelse "";
    if (std.mem.eql(u8, operation, "pii")) {
        const got = try middleware.PiiRedactor.redact(allocator, json.string(input, "text") orelse "");
        try check(std.mem.eql(u8, got, json.string(expect, "text") orelse ""));
    } else if (std.mem.eql(u8, operation, "pii-value")) {
        const value = json.get(input, "value") orelse json.Json{ .null = {} };
        const redacted = try redactValue(allocator, value);
        const parsed = try json.parse(allocator, redacted);
        try check(json.equals(parsed, json.get(expect, "value") orelse json.Json{ .null = {} }));
    } else if (std.mem.eql(u8, operation, "structured")) {
        const repair_output = json.string(input, "repairOutput");
        var structured = middleware.StructuredOutput{
            .schema = json.get(input, "schema") orelse json.Json{ .object = .empty },
            .max_repairs = json.integer(input, "maxRepairs", 0),
        };
        var repair_context = RepairContext{ .output = repair_output orelse "" };
        if (repair_output != null) {
            structured.repairer_ctx = &repair_context;
            structured.repairer = RepairContext.repair;
        }
        const result = try structured.apply(allocator, json.string(input, "output") orelse "");
        if (json.boolean(expect, "ok", false)) {
            try check(result.output != null and std.mem.eql(u8, result.output.?, json.string(expect, "output") orelse ""));
        } else {
            try check(std.mem.eql(u8, result.error_code orelse "", json.string(expect, "errorCode") orelse ""));
        }
    } else if (std.mem.eql(u8, operation, "call-limit")) {
        var limit = middleware.CallLimit{
            .model_limit = json.integer(input, "modelLimit", 0),
            .tool_limit = json.integer(input, "toolLimit", 0),
        };
        var outcomes = std.json.Array.init(allocator);
        for (json.array(input, "calls")) |call| {
            const result = if (std.mem.eql(u8, call.string, "model")) limit.beforeModel() else limit.beforeTool();
            if (result) |_| try outcomes.append(.{ .string = "ok" }) else |error_value| try outcomes.append(.{ .string = errorCode(error_value) });
        }
        try check(json.equals(.{ .array = outcomes }, json.get(expect, "outcomes") orelse json.Json{ .null = {} }));
    } else if (std.mem.eql(u8, operation, "tool-selection")) {
        var selected = std.array_list.Managed([]const u8).init(allocator);
        for (json.array(input, "selected")) |item| try selected.append(item.string);
        const selection = middleware.ToolSelection.init(selected.items);
        var tools = std.array_list.Managed(models.ToolSpec).init(allocator);
        for (json.array(input, "tools")) |item| try tools.append(.{ .name = item.string });
        const filtered = try selection.filter(allocator, tools.items);
        var advertised = std.json.Array.init(allocator);
        for (filtered) |tool| try advertised.append(.{ .string = tool.name });
        try check(json.equals(.{ .array = advertised }, json.get(expect, "advertised") orelse json.Json{ .null = {} }));
        const reject = selection.reject(json.string(input, "requested") orelse "");
        if (reject) |_| {
            try check(std.mem.eql(u8, "ok", json.string(expect, "reject") orelse ""));
        } else |error_value| {
            try check(std.mem.eql(u8, errorCode(error_value), json.string(expect, "reject") orelse ""));
        }
    } else if (std.mem.eql(u8, operation, "fallback")) {
        const content = json.string(input, "fallbackContent") orelse "";
        var fallback = FallbackContext{ .content = content };
        var failing = FailingContext{};
        var fallback_middleware = middleware.Fallback{
            .next = .{ .ctx = &failing, .callFn = FailingContext.call },
            .fallback = .{ .ctx = &fallback, .callFn = FallbackContext.call },
        };
        const response = try fallback_middleware.handler().call(.{});
        try check(std.mem.eql(u8, response.message.content orelse "", content));
    } else {
        return error.UnknownMiddleware;
    }
}

fn redactValue(allocator: Allocator, value: json.Json) ![]u8 {
    switch (value) {
        .string => |text| return json.stringify(allocator, .{ .string = try middleware.PiiRedactor.redact(allocator, text) }),
        .array => |items| {
            var out = std.array_list.Managed(u8).init(allocator);
            try out.append('[');
            for (items.items, 0..) |item, index| {
                if (index > 0) try out.append(',');
                try out.appendSlice(try redactValue(allocator, item));
            }
            try out.append(']');
            return out.toOwnedSlice();
        },
        .object => |items| {
            var out = std.array_list.Managed(u8).init(allocator);
            try out.append('{');
            var first = true;
            var iterator = items.iterator();
            while (iterator.next()) |entry| {
                if (!first) try out.append(',');
                first = false;
                try out.appendSlice(try json.stringify(allocator, .{ .string = entry.key_ptr.* }));
                try out.append(':');
                try out.appendSlice(try redactValue(allocator, entry.value_ptr.*));
            }
            try out.append('}');
            return out.toOwnedSlice();
        },
        else => return json.stringify(allocator, value),
    }
}

const FallbackContext = struct {
    content: []const u8,

    fn call(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = request;
        const self: *FallbackContext = @ptrCast(@alignCast(ctx));
        return .{ .message = .{ .role = models.ASSISTANT, .content = self.content } };
    }
};

const FailingContext = struct {
    fn call(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = ctx;
        _ = request;
        return error.PrimaryFailed;
    }
};

const ScriptedModel = struct {
    steps: []json.Json,
    next: usize = 0,

    fn model(self: *ScriptedModel) agent.Model {
        return .{ .ctx = self, .generateFn = generateFn };
    }

    fn generateFn(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        _ = request;
        const self: *ScriptedModel = @ptrCast(@alignCast(ctx));
        if (self.next >= self.steps.len) return error.ScriptExhausted;
        const step = self.steps[self.next];
        self.next += 1;
        var calls = std.array_list.Managed(models.ToolCall).init(std.heap.page_allocator);
        for (json.array(step, "toolCalls")) |item| {
            try calls.append(.{
                .id = json.string(item, "id") orelse "",
                .name = json.string(item, "name") orelse "",
                .arguments = json.get(item, "arguments") orelse json.Json{ .object = .empty },
            });
        }
        return .{
            .message = .{
                .role = models.ASSISTANT,
                .content = json.string(step, "content"),
                .tool_calls = calls.items,
            },
            .usage = .{
                .input_tokens = json.integer(step, "inputTokens", 0),
                .output_tokens = json.integer(step, "outputTokens", 0),
            },
        };
    }
};

const EchoTool = struct {
    name: []const u8,
    description: []const u8,
    calls: *usize,

    fn tool(self: *EchoTool) agent.Tool {
        return .{ .ctx = self, .name = self.name, .description = self.description, .invokeFn = invokeFn };
    }

    fn invokeFn(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
        const self: *EchoTool = @ptrCast(@alignCast(ctx));
        self.calls.* += 1;
        return arguments;
    }
};

fn runAgentLoop(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    var invocations: usize = 0;
    var registry = agent.Registry.init(allocator);
    for (json.array(input, "tools")) |item| {
        var tool = EchoTool{
            .name = json.string(item, "name") orelse "",
            .description = json.string(item, "description") orelse "",
            .calls = &invocations,
        };
        try registry.register(tool.tool());
    }
    var model = ScriptedModel{ .steps = @constCast(json.array(input, "script")) };
    var sink = RecordingSink.init(allocator);
    const options = agent.AgentOptions{
        .model = model.model(),
        .tools = &registry,
        .events = sink.sink(),
        .max_steps = json.integer(input, "maxSteps", 0),
        .max_tokens = json.integer(input, "maxTokens", 0),
    };
    const run_result = agent.runAgent(allocator, options, .{ .id = "s1" }, json.string(input, "prompt") orelse "");
    var value: ?models.RunResult = null;
    var failure: ?anyerror = null;
    if (run_result) |response| {
        value = response;
    } else |error_value| {
        failure = error_value;
    }
    if (json.boolean(expect, "error", false)) {
        try check(failure != null);
        if (json.string(expect, "errorCode")) |code| {
            try check(std.mem.eql(u8, errorCode(failure.?), code));
        }
    } else {
        try check(failure == null);
        const result = value.?;
        try check(std.mem.eql(u8, result.output, json.string(expect, "output") orelse ""));
        try check(result.steps == json.integer(expect, "steps", 0));
    }
    try check(invocations == json.integer(expect, "toolInvocations", 0));
    var events = std.json.Array.init(allocator);
    for (sink.types.items) |kind| try events.append(.{ .string = kind });
    const expected = json.get(expect, "events") orelse json.Json{ .null = {} };
    if (sink.types.items.len == 0) {
        try check(expected == .null);
    } else {
        try check(json.equals(.{ .array = events }, expected));
    }
}

pub fn run(allocator: Allocator, group: []const u8, vector: json.Json) !void {
    const input = json.get(vector, "input") orelse json.Json{ .object = .empty };
    const expect = json.get(vector, "expect") orelse json.Json{ .object = .empty };
    if (std.mem.eql(u8, group, "memory")) return runMemory(allocator, input, expect);
    if (std.mem.eql(u8, group, "event")) return runEvent(allocator, input, expect);
    if (std.mem.eql(u8, group, "stream")) return runStream(allocator, expect);
    if (std.mem.eql(u8, group, "checkpoint")) return runCheckpoint(allocator, input, expect);
    if (std.mem.eql(u8, group, "policy")) return runPolicy(allocator, input, expect);
    if (std.mem.eql(u8, group, "context")) return runContext(allocator, input, expect);
    if (std.mem.eql(u8, group, "middleware")) return runMiddleware(allocator, input, expect);
    if (std.mem.eql(u8, group, "agent-loop")) return runAgentLoop(allocator, input, expect);
    return error.UnknownGroup;
}
