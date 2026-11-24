const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const json = praxo.json;
const models = praxo.models;

const GATEWAY_ID = "gateway-100";

const GatewayAdapter = struct {
    ctx: *anyopaque,
    readFn: *const fn (ctx: *anyopaque, device: []const u8) anyerror!json.Json,

    fn read(self: GatewayAdapter, device: []const u8) !json.Json {
        return self.readFn(self.ctx, device);
    }
};

const FixtureGateway = struct {
    allocator: std.mem.Allocator,
    simulate_failure: bool,
    budget_bytes: usize = 4096,
    peak_bytes: usize = 0,
    used_bytes: usize = 0,

    fn adapter(self: *FixtureGateway) GatewayAdapter {
        return .{ .ctx = @ptrCast(self), .readFn = read };
    }

    fn read(ctx: *anyopaque, device: []const u8) anyerror!json.Json {
        const self: *FixtureGateway = @ptrCast(@alignCast(ctx));
        if (self.simulate_failure) return error.GatewayReadFailed;
        const scratch_bytes: usize = 128;
        if (self.used_bytes + scratch_bytes > self.budget_bytes) return error.BudgetExceeded;
        const scratch = try self.allocator.alloc(u8, scratch_bytes);
        self.used_bytes += scratch_bytes;
        if (self.used_bytes > self.peak_bytes) self.peak_bytes = self.used_bytes;
        @memset(scratch, 0);
        self.allocator.free(scratch);
        self.used_bytes -= scratch_bytes;
        var snapshot = std.json.ObjectMap.empty;

        try snapshot.put(self.allocator, "device_id", .{ .string = device });
        try snapshot.put(self.allocator, "health", .{ .string = "degraded" });
        try snapshot.put(self.allocator, "uptime_s", .{ .integer = 86400 });
        try snapshot.put(self.allocator, "disk_percent", .{ .integer = 91 });
        try snapshot.put(self.allocator, "memory_percent", .{ .integer = 78 });
        try snapshot.put(self.allocator, "link", .{ .string = "mqtt-bridge" });
        try snapshot.put(self.allocator, "source", .{ .string = "adapter_fixture" });
        try snapshot.put(self.allocator, "budget_bytes", .{ .integer = @intCast(self.budget_bytes) });
        try snapshot.put(self.allocator, "peak_bytes", .{ .integer = @intCast(self.peak_bytes) });
        try snapshot.put(self.allocator, "used_bytes", .{ .integer = @intCast(self.used_bytes) });
        return .{ .object = snapshot };
    }
};

const ReadToolContext = struct {
    adapter: GatewayAdapter,
    reads: usize = 0,
};

fn invokeRead(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *ReadToolContext = @ptrCast(@alignCast(ctx));
    self.reads += 1;
    const device = json.string(arguments, "device_id") orelse GATEWAY_ID;
    return self.adapter.read(device);
}

const DraftToolContext = struct {
    allocator: std.mem.Allocator,
};

fn invokeDraft(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *DraftToolContext = @ptrCast(@alignCast(ctx));
    const device = json.string(arguments, "device_id") orelse GATEWAY_ID;
    const action = json.string(arguments, "action") orelse "restart_telemetry";
    var draft = std.json.ObjectMap.empty;
    try draft.put(self.allocator, "draft_id", .{ .string = "draft-100" });
    try draft.put(self.allocator, "device_id", .{ .string = device });
    try draft.put(self.allocator, "action", .{ .string = action });
    try draft.put(self.allocator, "status", .{ .string = "draft_only" });
    try draft.put(self.allocator, "review_required", .{ .bool = true });
    try draft.put(self.allocator, "device_writes", .{ .integer = 0 });
    return .{ .object = draft };
}

fn argumentString(arguments: ?json.Json, key: []const u8) []const u8 {
    if (arguments) |value| return json.string(value, key) orelse "";
    return "";
}

fn policy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) {
        return .{ .allowed = true, .reason = "deterministic gateway diagnosis" };
    }
    if (!std.mem.eql(u8, action.kind, "tool.invoke")) {
        return .{ .allowed = false, .reason = "unsupported action" };
    }
    const name = action.tool_name orelse return .{ .allowed = false, .reason = "missing tool" };
    const device = argumentString(action.arguments, "device_id");
    const draft_action = argumentString(action.arguments, "action");
    const in_scope = std.mem.eql(u8, device, GATEWAY_ID);
    if (std.mem.eql(u8, name, "read_gateway")) {
        return .{
            .allowed = in_scope,
            .reason = "only gateway-100 read is allowed",
        };
    }
    if (std.mem.eql(u8, name, "draft_action")) {
        return .{
            .allowed = in_scope and std.mem.eql(u8, draft_action, "restart_telemetry"),
            .reason = "only gateway-100 restart_telemetry draft is allowed",
        };
    }
    return .{ .allowed = false, .reason = "unknown tool" };
}

fn toolResponse(allocator: std.mem.Allocator, id: []const u8, name: []const u8, arguments: json.Json) !models.Response {
    const calls = try allocator.alloc(models.ToolCall, 1);
    calls[0] = .{ .id = id, .name = name, .arguments = arguments };
    return .{ .message = .{ .role = models.ASSISTANT, .content = "", .tool_calls = calls } };
}

const FixtureModel = struct {
    allocator: std.mem.Allocator,
    device: []const u8,

    fn model(self: *FixtureModel) agent.Model {
        return .{ .ctx = @ptrCast(self), .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *FixtureModel = @ptrCast(@alignCast(ctx));
        var gateway_content: ?[]const u8 = null;
        var draft_content: ?[]const u8 = null;
        var tool_index: usize = 0;
        for (request.messages) |message| {
            if (!std.mem.eql(u8, message.role, models.TOOL)) continue;
            if (tool_index == 0) gateway_content = message.content;
            if (tool_index == 1) draft_content = message.content;
            tool_index += 1;
        }
        if (tool_index == 0) {
            var arguments = std.json.ObjectMap.empty;
            try arguments.put(self.allocator, "device_id", .{ .string = self.device });
            return toolResponse(self.allocator, "read-1", "read_gateway", .{ .object = arguments });
        }
        if (tool_index == 1) {
            var arguments = std.json.ObjectMap.empty;
            try arguments.put(self.allocator, "device_id", .{ .string = self.device });
            try arguments.put(self.allocator, "action", .{ .string = "restart_telemetry" });
            try arguments.put(self.allocator, "reason", .{ .string = "disk pressure and degraded health" });
            return toolResponse(self.allocator, "draft-1", "draft_action", .{ .object = arguments });
        }
        const gateway = try json.parse(self.allocator, gateway_content orelse "null");
        const draft = try json.parse(self.allocator, draft_content orelse "null");
        var report = std.json.ObjectMap.empty;
        try report.put(self.allocator, "gateway", gateway);
        try report.put(self.allocator, "draft", draft);
        try report.put(self.allocator, "policy", .{ .string = "read and draft only; device writes remain application-owned" });
        try report.put(self.allocator, "device_writes", .{ .integer = 0 });
        const text = try json.stringify(self.allocator, .{ .object = report });
        return .{ .message = .{ .role = models.ASSISTANT, .content = text } };
    }
};

fn runScenario(allocator: std.mem.Allocator, device: []const u8, simulate_failure: bool, budget_bytes: usize, reads: *usize) !models.RunResult {
    var fixture = FixtureGateway{ .allocator = allocator, .simulate_failure = simulate_failure, .budget_bytes = budget_bytes };
    var read_context = ReadToolContext{ .adapter = fixture.adapter() };
    var draft_context = DraftToolContext{ .allocator = allocator };

    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = &read_context,
        .name = "read_gateway",
        .description = "Read gateway health through an application-owned adapter contract.",
        .invokeFn = invokeRead,
    });
    try registry.register(.{
        .ctx = &draft_context,
        .name = "draft_action",
        .description = "Draft an operator review action without a device write.",
        .invokeFn = invokeDraft,
    });

    var model = FixtureModel{ .allocator = allocator, .device = device };
    var policy_context: u8 = 0;
    const allowed_tools = [_][]const u8{ "read_gateway", "draft_action" };
    var gateway_agent = agent.Agent.init(.{
        .model = model.model(),
        .tools = &registry,
        .max_steps = 5,
        .allowed_tools = &allowed_tools,
        .policy = policy,
        .policy_ctx = @ptrCast(&policy_context),
        .require_policy = true,
        .require_tool_scope = true,
    });
    const result = gateway_agent.run(
        allocator,
        .{ .id = "zig-gateway" },
        "Diagnose the fixed gateway health and draft an operator review action.",
    ) catch |failure| {
        reads.* = read_context.reads;
        return failure;
    };
    reads.* = read_context.reads;
    return result;
}

fn expectString(actual: ?[]const u8, expected: []const u8) !void {
    const value = actual orelse return error.VerificationFailed;
    if (!std.mem.eql(u8, value, expected)) return error.VerificationFailed;
}

fn runTests(allocator: std.mem.Allocator) !void {
    var reads: usize = 0;
    const success = runScenario(allocator, GATEWAY_ID, false, 4096, &reads) catch |failure| {
        std.debug.print("success path failed: {s}\n", .{@errorName(failure)});
        return failure;
    };
    const report = try json.parse(allocator, success.output);
    const gateway = json.get(report, "gateway") orelse return error.VerificationFailed;
    const draft = json.get(report, "draft") orelse return error.VerificationFailed;
    try expectString(json.string(gateway, "device_id"), GATEWAY_ID);
    try expectString(json.string(gateway, "health"), "degraded");
    if (json.integer(gateway, "disk_percent", 0) != 91) return error.VerificationFailed;
    if (json.integer(gateway, "budget_bytes", 0) != 4096) return error.VerificationFailed;
    if (json.integer(gateway, "peak_bytes", 0) != 128) return error.VerificationFailed;
    if (json.integer(gateway, "used_bytes", 1) != 0) return error.VerificationFailed;
    if (json.integer(report, "device_writes", 1) != 0) return error.VerificationFailed;
    try expectString(json.string(draft, "status"), "draft_only");
    try expectString(json.string(draft, "action"), "restart_telemetry");
    if (!json.boolean(draft, "review_required", false)) return error.VerificationFailed;
    if (reads != 1) return error.VerificationFailed;
    std.debug.print("success: gateway-100 health=degraded action=restart_telemetry status=draft_only writes=0 reads=1\n", .{});

    var denied_reads: usize = 0;
    if (runScenario(allocator, "gateway-200", false, 4096, &denied_reads)) |_| {
        return error.VerificationFailed;
    } else |failure| {
        if (failure != error.PolicyError or denied_reads != 0) return error.VerificationFailed;
    }
    std.debug.print("deny: PolicyError reads=0\n", .{});

    var failure_reads: usize = 0;
    if (runScenario(allocator, GATEWAY_ID, true, 4096, &failure_reads)) |_| {
        return error.VerificationFailed;
    } else |failure| {
        if (failure != error.GatewayReadFailed or failure_reads != 1) return error.VerificationFailed;
    }
    std.debug.print("failure: GatewayReadFailed reads=1\n", .{});

    var tight_reads: usize = 0;
    if (runScenario(allocator, GATEWAY_ID, false, 64, &tight_reads)) |_| {
        return error.VerificationFailed;
    } else |failure| {
        if (failure != error.BudgetExceeded or tight_reads != 1) return error.VerificationFailed;
    }
    std.debug.print("failure: BudgetExceeded reads=1\n", .{});
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var arguments = try std.process.Args.Iterator.initAllocator(minimal.args, allocator);
    defer arguments.deinit();
    _ = arguments.skip();

    var test_mode = false;
    var simulate_failure = false;
    var tight_budget = false;
    var device: []const u8 = GATEWAY_ID;
    while (arguments.next()) |argument| {
        if (std.mem.eql(u8, argument, "--test")) {
            test_mode = true;
        } else if (std.mem.eql(u8, argument, "--simulate-failure")) {
            simulate_failure = true;
        } else if (std.mem.eql(u8, argument, "--tight-budget")) {
            tight_budget = true;
        } else if (std.mem.eql(u8, argument, "--device")) {
            const value = arguments.next() orelse return error.MissingDeviceValue;
            device = try allocator.dupe(u8, value);
        }
    }

    if (test_mode) {
        try runTests(allocator);
        return;
    }

    var reads: usize = 0;
    const result = runScenario(allocator, device, simulate_failure, if (tight_budget) 64 else 4096, &reads) catch |failure| {
        std.debug.print("error: {s} reads={d}\n", .{ @errorName(failure), reads });
        std.process.exit(if (failure == error.PolicyError) 2 else 1);
    };
    std.debug.print("{s}\nreads={d}\n", .{ result.output, reads });
}

