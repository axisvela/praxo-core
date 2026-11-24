const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const json = praxo.json;
const models = praxo.models;

const FLEET_ID = "drone-100";

const FleetAdapter = struct {
    ctx: *anyopaque,
    readFn: *const fn (ctx: *anyopaque, drone: []const u8) anyerror!json.Json,

    fn read(self: FleetAdapter, drone: []const u8) !json.Json {
        return self.readFn(self.ctx, drone);
    }
};

const FixtureFleet = struct {
    allocator: std.mem.Allocator,
    simulate_failure: bool,

    fn adapter(self: *FixtureFleet) FleetAdapter {
        return .{ .ctx = @ptrCast(self), .readFn = read };
    }

    fn read(ctx: *anyopaque, drone: []const u8) anyerror!json.Json {
        const self: *FixtureFleet = @ptrCast(@alignCast(ctx));
        if (self.simulate_failure) return error.FleetUnavailable;
        var snapshot = std.json.ObjectMap.empty;
        try snapshot.put(self.allocator, "drone_id", .{ .string = drone });
        try snapshot.put(self.allocator, "battery_pct", .{ .integer = 72 });
        try snapshot.put(self.allocator, "waypoints", .{ .integer = 3 });
        try snapshot.put(self.allocator, "conflict_zone", .{ .string = "Z-3" });
        try snapshot.put(self.allocator, "source", .{ .string = "fleet_fixture" });
        return .{ .object = snapshot };
    }
};

const ReadToolContext = struct {
    adapter: FleetAdapter,
    reads: usize = 0,
};

fn invokeRead(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *ReadToolContext = @ptrCast(@alignCast(ctx));
    self.reads += 1;
    const drone = json.string(arguments, "drone_id") orelse FLEET_ID;
    return self.adapter.read(drone);
}

const DraftToolContext = struct {
    allocator: std.mem.Allocator,
    drafts: usize = 0,
};

fn invokeDraft(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *DraftToolContext = @ptrCast(@alignCast(ctx));
    self.drafts += 1;
    const drone = json.string(arguments, "drone_id") orelse FLEET_ID;
    const action = json.string(arguments, "action") orelse "draft_waypoints";
    var draft = std.json.ObjectMap.empty;
    try draft.put(self.allocator, "plan_id", .{ .string = "flight-plan-100" });
    try draft.put(self.allocator, "drone_id", .{ .string = drone });
    try draft.put(self.allocator, "action", .{ .string = action });
    try draft.put(self.allocator, "waypoints_planned", .{ .integer = 3 });
    try draft.put(self.allocator, "conflict_review", .{ .bool = true });
    try draft.put(self.allocator, "status", .{ .string = "draft_only" });
    try draft.put(self.allocator, "review_required", .{ .bool = true });
    try draft.put(self.allocator, "flight_commands", .{ .integer = 0 });
    return .{ .object = draft };
}

fn argumentString(arguments: ?json.Json, key: []const u8) []const u8 {
    if (arguments) |value| return json.string(value, key) orelse "";
    return "";
}

fn policy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) {
        return .{ .allowed = true, .reason = "deterministic fleet planning" };
    }
    if (!std.mem.eql(u8, action.kind, "tool.invoke")) {
        return .{ .allowed = false, .reason = "unsupported action" };
    }
    const name = action.tool_name orelse return .{ .allowed = false, .reason = "missing tool" };
    const drone = argumentString(action.arguments, "drone_id");
    const draft_action = argumentString(action.arguments, "action");
    const in_scope = std.mem.eql(u8, drone, FLEET_ID);
    if (std.mem.eql(u8, name, "read_fleet")) {
        return .{
            .allowed = in_scope,
            .reason = "only drone-100 read is allowed",
        };
    }
    if (std.mem.eql(u8, name, "draft_flight_plan")) {
        return .{
            .allowed = in_scope and std.mem.eql(u8, draft_action, "draft_waypoints"),
            .reason = "only drone-100 draft_waypoints is allowed",
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
    drone: []const u8,

    fn model(self: *FixtureModel) agent.Model {
        return .{ .ctx = @ptrCast(self), .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *FixtureModel = @ptrCast(@alignCast(ctx));
        var fleet_content: ?[]const u8 = null;
        var draft_content: ?[]const u8 = null;
        var tool_index: usize = 0;
        for (request.messages) |message| {
            if (!std.mem.eql(u8, message.role, models.TOOL)) continue;
            if (tool_index == 0) fleet_content = message.content;
            if (tool_index == 1) draft_content = message.content;
            tool_index += 1;
        }
        if (tool_index == 0) {
            var arguments = std.json.ObjectMap.empty;
            try arguments.put(self.allocator, "drone_id", .{ .string = self.drone });
            return toolResponse(self.allocator, "read-1", "read_fleet", .{ .object = arguments });
        }
        if (tool_index == 1) {
            var arguments = std.json.ObjectMap.empty;
            try arguments.put(self.allocator, "drone_id", .{ .string = self.drone });
            try arguments.put(self.allocator, "action", .{ .string = "draft_waypoints" });
            return toolResponse(self.allocator, "plan-1", "draft_flight_plan", .{ .object = arguments });
        }
        const fleet = try json.parse(self.allocator, fleet_content orelse "null");
        const plan = try json.parse(self.allocator, draft_content orelse "null");
        var report = std.json.ObjectMap.empty;
        try report.put(self.allocator, "fleet", fleet);
        try report.put(self.allocator, "plan", plan);
        try report.put(self.allocator, "policy", .{ .string = "read and draft only; conflict checks and flight commands remain application-owned" });
        try report.put(self.allocator, "flight_commands", .{ .integer = 0 });
        const text = try json.stringify(self.allocator, .{ .object = report });
        return .{ .message = .{ .role = models.ASSISTANT, .content = text } };
    }
};

fn runScenario(allocator: std.mem.Allocator, drone: []const u8, simulate_failure: bool, reads: *usize, drafts: *usize) !models.RunResult {
    var fixture = FixtureFleet{ .allocator = allocator, .simulate_failure = simulate_failure };
    var read_context = ReadToolContext{ .adapter = fixture.adapter() };
    var draft_context = DraftToolContext{ .allocator = allocator };

    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = &read_context,
        .name = "read_fleet",
        .description = "Read fixed drone waypoint state through an application-owned adapter.",
        .invokeFn = invokeRead,
    });
    try registry.register(.{
        .ctx = &draft_context,
        .name = "draft_flight_plan",
        .description = "Draft a review-only flight plan; never commands a drone.",
        .invokeFn = invokeDraft,
    });

    var model = FixtureModel{ .allocator = allocator, .drone = drone };
    var policy_context: u8 = 0;
    const allowed_tools = [_][]const u8{ "read_fleet", "draft_flight_plan" };
    var fleet_agent = agent.Agent.init(.{
        .model = model.model(),
        .tools = &registry,
        .max_steps = 5,
        .allowed_tools = &allowed_tools,
        .policy = policy,
        .policy_ctx = @ptrCast(&policy_context),
        .require_policy = true,
        .require_tool_scope = true,
    });
    const result = fleet_agent.run(
        allocator,
        .{ .id = "zig-drone-fleet-plan" },
        "Read the fixed drone and draft a review-only waypoint plan.",
    ) catch |failure| {
        reads.* = read_context.reads;
        drafts.* = draft_context.drafts;
        return failure;
    };
    reads.* = read_context.reads;
    drafts.* = draft_context.drafts;
    return result;
}

fn expectString(actual: ?[]const u8, expected: []const u8) !void {
    const value = actual orelse return error.VerificationFailed;
    if (!std.mem.eql(u8, value, expected)) return error.VerificationFailed;
}

fn runTests(allocator: std.mem.Allocator) !void {
    var reads: usize = 0;
    var drafts: usize = 0;
    const success = runScenario(allocator, FLEET_ID, false, &reads, &drafts) catch |failure| {
        std.debug.print("success path failed: {s}\n", .{@errorName(failure)});
        return failure;
    };
    const report = try json.parse(allocator, success.output);
    const fleet = json.get(report, "fleet") orelse return error.VerificationFailed;
    const plan = json.get(report, "plan") orelse return error.VerificationFailed;
    try expectString(json.string(fleet, "drone_id"), FLEET_ID);
    if (json.integer(fleet, "battery_pct", 0) != 72) return error.VerificationFailed;
    if (json.integer(fleet, "waypoints", 0) != 3) return error.VerificationFailed;
    try expectString(json.string(plan, "status"), "draft_only");
    try expectString(json.string(plan, "action"), "draft_waypoints");
    if (json.integer(plan, "waypoints_planned", 0) != 3) return error.VerificationFailed;
    if (!json.boolean(plan, "conflict_review", false)) return error.VerificationFailed;
    if (json.integer(plan, "flight_commands", 1) != 0) return error.VerificationFailed;
    if (json.integer(report, "flight_commands", 1) != 0) return error.VerificationFailed;
    if (reads != 1 or drafts != 1) return error.VerificationFailed;
    std.debug.print("success: drone-100 battery_pct=72 waypoints=3 status=draft_only conflict_review=true commands=0 reads=1\n", .{});

    var denied_reads: usize = 0;
    var denied_drafts: usize = 0;
    if (runScenario(allocator, "drone-200", false, &denied_reads, &denied_drafts)) |_| {
        return error.VerificationFailed;
    } else |failure| {
        if (failure != error.PolicyError or denied_reads != 0 or denied_drafts != 0) return error.VerificationFailed;
    }
    std.debug.print("deny: PolicyError reads=0\n", .{});

    var failure_reads: usize = 0;
    var failure_drafts: usize = 0;
    if (runScenario(allocator, FLEET_ID, true, &failure_reads, &failure_drafts)) |_| {
        return error.VerificationFailed;
    } else |failure| {
        if (failure != error.FleetUnavailable or failure_reads != 1 or failure_drafts != 0) return error.VerificationFailed;
    }
    std.debug.print("failure: FleetUnavailable reads=1\n", .{});
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
    var drone: []const u8 = FLEET_ID;
    while (arguments.next()) |argument| {
        if (std.mem.eql(u8, argument, "--test")) {
            test_mode = true;
        } else if (std.mem.eql(u8, argument, "--simulate-failure")) {
            simulate_failure = true;
        } else if (std.mem.eql(u8, argument, "--drone")) {
            const value = arguments.next() orelse return error.MissingDroneValue;
            drone = try allocator.dupe(u8, value);
        }
    }

    if (test_mode) {
        try runTests(allocator);
        return;
    }

    var reads: usize = 0;
    var drafts: usize = 0;
    const result = runScenario(allocator, drone, simulate_failure, &reads, &drafts) catch |failure| {
        std.debug.print("error: {s} reads={d} drafts={d}\n", .{ @errorName(failure), reads, drafts });
        std.process.exit(if (failure == error.PolicyError) 2 else 1);
    };
    std.debug.print("{s}\nreads={d}\ndrafts={d}\n", .{ result.output, reads, drafts });
}
