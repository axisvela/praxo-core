const std = @import("std");
const agent = @import("agent");
const json = @import("json");
const models = @import("models");
const openai = @import("openaicompat");

const TimeContext = struct {
    allocator: std.mem.Allocator,
};

fn invokeTime(ctx: *anyopaque, arguments: json.Json) anyerror!json.Json {
    const self: *TimeContext = @ptrCast(@alignCast(ctx));
    var zone: []const u8 = "utc";
    if (json.string(arguments, "zone")) |value| {
        if (value.len > 0) zone = value;
    }
    const now = std.Io.Clock.real.now(std.Io.Threaded.global_single_threaded.io());
    const per_second: i96 = std.time.ns_per_s;
    const seconds: i64 = @intCast(@divFloor(now.nanoseconds, per_second));
    return .{ .string = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ zone, seconds }) };
}

fn policy(_: *anyopaque, action: models.Action) models.Decision {
    if (std.mem.eql(u8, action.kind, "model.generate")) {
        return .{ .allowed = true, .reason = "model generation" };
    }
    if (std.mem.eql(u8, action.kind, "tool.invoke")) {
        const name = action.tool_name orelse return .{ .allowed = false };
        return .{
            .allowed = std.mem.eql(u8, name, "get_time"),
            .reason = "only get_time is permitted",
        };
    }
    return .{ .allowed = false, .reason = "unsupported action" };
}

fn envOr(
    allocator: std.mem.Allocator,
    name: []const u8,
    fallback: []const u8,
) ![]const u8 {
    const value = std.process.getEnvVarOwned(allocator, name) catch |failure| switch (failure) {
        error.EnvironmentVariableNotFound => return fallback,
        else => return failure,
    };
    if (value.len == 0) return fallback;
    return value;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_url = try envOr(allocator, "PRAXO_BASE_URL", "http://localhost:11434/v1");
    const model_name = try envOr(allocator, "PRAXO_MODEL", "qwen3.5:4b");
    const api_key = try envOr(allocator, "PRAXO_API_KEY", "");
    const prompt = try envOr(
        allocator,
        "PRAXO_PROMPT",
        "What time is it? Use get_time with zone set to utc and reply with the time.",
    );

    var adapter = openai.Adapter.init(allocator, base_url, model_name);
    adapter.api_key = api_key;

    var time_context = TimeContext{ .allocator = allocator };
    var registry = agent.Registry.init(allocator);
    try registry.register(.{
        .ctx = &time_context,
        .name = "get_time",
        .description = "Return the current time for the requested zone as <zone>:<epoch-seconds>.",
        .invokeFn = invokeTime,
    });

    const allowed_tools = [_][]const u8{"get_time"};
    var instance = agent.Agent.init(.{
        .model = adapter.asModel(),
        .tools = &registry,
        .system_prompt = "You are a concise assistant. Use the provided tools when they help.",
        .max_steps = 4,
        .allowed_tools = &allowed_tools,
        .policy = policy,
        .policy_ctx = @ptrCast(&time_context),
    });

    const result = instance.run(allocator, .{ .id = "live-model" }, prompt) catch |failure| {
        std.debug.print(
            "live model run failed: {s}\n\nCheck PRAXO_BASE_URL ({s}), PRAXO_MODEL ({s}), and PRAXO_API_KEY\n",
            .{ @errorName(failure), base_url, model_name },
        );
        return failure;
    };
    std.debug.print("{s}\n", .{result.output});
}
