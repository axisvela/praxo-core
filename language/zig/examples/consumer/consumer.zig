const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const json = praxo.json;
const models = praxo.models;

const ToolContext = struct {
    calls: usize = 0,
};

fn invokeTool(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *ToolContext = @ptrCast(@alignCast(ctx));
    _ = arguments;
    self.calls += 1;
    return .{ .string = "recorded" };
}

const Fixture = struct {
    allocator: std.mem.Allocator,
    target: []const u8,

    fn model(self: *Fixture) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *Fixture = @ptrCast(@alignCast(ctx));
        const last = request.messages[request.messages.len - 1];
        if (std.mem.eql(u8, last.role, models.TOOL)) {
            return .{ .message = .{ .role = models.ASSISTANT, .content = "recorded" } };
        }
        var arguments = std.json.ObjectMap.empty;
        try arguments.put(self.allocator, "target", .{ .string = self.target });
        const calls = try self.allocator.alloc(models.ToolCall, 1);
        calls[0] = .{
            .id = "record-1",
            .name = "record",
            .arguments = .{ .object = arguments },
        };
        return .{ .message = .{
            .role = models.ASSISTANT,
            .content = "",
            .tool_calls = calls,
        } };
    }
};

fn policy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) {
        return .{ .allowed = true, .reason = "model generation" };
    }
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        if (!std.mem.eql(u8, name, "record")) {
            return .{ .allowed = false, .reason = "only record is permitted" };
        }
        const target = if (action.arguments) |arguments|
            json.string(arguments, "target") orelse ""
        else
            "";
        return .{
            .allowed = std.mem.eql(u8, target, "public"),
            .reason = "only the public target is permitted",
        };
    }
    return .{ .allowed = false, .reason = "unsupported action" };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const allowed_tools = [_][]const u8{"record"};

    var allowed_context = ToolContext{};
    var allowed_registry = agent.Registry.init(allocator);
    try allowed_registry.register(.{
        .ctx = &allowed_context,
        .name = "record",
        .description = "Record a target in an in-memory counter.",
        .invokeFn = invokeTool,
    });
    var allowed_fixture = Fixture{ .allocator = allocator, .target = "public" };
    var allowed_agent = agent.Agent.init(.{
        .model = allowed_fixture.model(),
        .tools = &allowed_registry,
        .max_steps = 3,
        .allowed_tools = &allowed_tools,
        .policy = policy,
        .policy_ctx = @ptrCast(&allowed_context),
    });
    const allowed = try allowed_agent.run(
        allocator,
        .{ .id = "consumer-public" },
        "Record the requested target.",
    );
    if (!std.mem.eql(u8, allowed.output, "recorded") or allowed_context.calls != 1) {
        std.debug.print(
            "allow verification failed: output={s} effects={d}\n",
            .{ allowed.output, allowed_context.calls },
        );
        return error.AllowVerificationFailed;
    }
    std.debug.print("allow: recorded; effects=1\n", .{});

    var denied_context = ToolContext{};
    var denied_registry = agent.Registry.init(allocator);
    try denied_registry.register(.{
        .ctx = &denied_context,
        .name = "record",
        .description = "Record a target in an in-memory counter.",
        .invokeFn = invokeTool,
    });
    var denied_fixture = Fixture{ .allocator = allocator, .target = "private" };
    var denied_agent = agent.Agent.init(.{
        .model = denied_fixture.model(),
        .tools = &denied_registry,
        .max_steps = 3,
        .allowed_tools = &allowed_tools,
        .policy = policy,
        .policy_ctx = @ptrCast(&denied_context),
    });
    if (denied_agent.run(
        allocator,
        .{ .id = "consumer-private" },
        "Record the requested target.",
    )) |_| {
        std.debug.print("private target was not denied\n", .{});
        return error.PrivateTargetAllowed;
    } else |failure| {
        if (failure != error.PolicyError or denied_context.calls != 0) {
            std.debug.print(
                "deny verification failed: code={s} effects={d}\n",
                .{ @errorName(failure), denied_context.calls },
            );
            return error.DenyVerificationFailed;
        }
    }
    std.debug.print("deny: policy rejected; effects=0\n", .{});
}
