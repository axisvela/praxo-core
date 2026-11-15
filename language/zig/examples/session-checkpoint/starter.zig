const std = @import("std");
const praxo = @import("praxo");
const agent = praxo.agent;
const json = praxo.json;
const models = praxo.models;
const runtime = praxo.runtime;

const checkpoint_type = "session";
const session_id = "session-1";

pub const Outcome = struct {
    restored_messages: usize,
    output: []const u8,
};

const TurnModel = struct {
    allocator: std.mem.Allocator,

    fn model(self: *TurnModel) agent.Model {
        return .{ .ctx = self, .generateFn = generate };
    }

    fn generate(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *TurnModel = @ptrCast(@alignCast(ctx));
        const content = try std.fmt.allocPrint(self.allocator, "turn {d}", .{request.messages.len});
        return .{ .message = .{ .role = models.ASSISTANT, .content = content } };
    }
};

const MemoryStore = struct {
    allocator: std.mem.Allocator,
    records: std.StringHashMap([]const u8),

    fn init(allocator: std.mem.Allocator) MemoryStore {
        return .{ .allocator = allocator, .records = std.StringHashMap([]const u8).init(allocator) };
    }

    fn save(self: *MemoryStore, id: []const u8, payload: []const u8) !void {
        try self.records.put(id, payload);
    }

    fn load(self: *MemoryStore, id: []const u8) ![]const u8 {
        return self.records.get(id) orelse error.CheckpointNotFound;
    }
};

fn saveSession(
    allocator: std.mem.Allocator,
    allow: *runtime.CheckpointAllowlist,
    messages: []const models.Message,
) ![]const u8 {
    var wire = std.json.Array.init(allocator);
    for (messages) |message| try wire.append(try models.messageWire(allocator, message));
    var payload = std.json.ObjectMap.empty;
    try payload.put(allocator, "messages", .{ .array = wire });
    return allow.marshal(checkpoint_type, .{ .object = payload });
}

fn restoreHistory(
    history: *std.array_list.Managed(models.Message),
    value: json.Json,
) !void {
    history.clearRetainingCapacity();
    for (json.array(value, "messages")) |item| {
        try history.append(.{
            .role = json.string(item, "role") orelse "",
            .content = json.string(item, "content"),
        });
    }
}

pub fn run(allocator: std.mem.Allocator) !Outcome {
    var allow = runtime.CheckpointAllowlist.init(allocator);
    try allow.register(checkpoint_type);
    var store = MemoryStore.init(allocator);
    var history = std.array_list.Managed(models.Message).init(allocator);
    try history.append(.{ .role = models.USER, .content = "first" });
    try history.append(.{ .role = models.ASSISTANT, .content = "ack" });
    try store.save(session_id, try saveSession(allocator, &allow, history.items));

    var turn_model = TurnModel{ .allocator = allocator };
    const options = agent.AgentOptions{ .model = turn_model.model(), .max_steps = 2 };

    try restoreHistory(&history, try allow.unmarshal(try store.load(session_id)));
    var session = models.Session{ .id = session_id, .messages = history.items };
    const second = try agent.runAgent(allocator, options, session, "second");
    if (!std.mem.eql(u8, second.output, "turn 3")) return error.UnexpectedSecondTurn;

    try history.append(.{ .role = models.USER, .content = "second" });
    try history.append(.{ .role = models.ASSISTANT, .content = second.output });
    try store.save(session_id, try saveSession(allocator, &allow, history.items));

    try restoreHistory(&history, try allow.unmarshal(try store.load(session_id)));
    session = .{ .id = session_id, .messages = history.items };
    const third = try agent.runAgent(allocator, options, session, "third");
    if (!std.mem.eql(u8, third.output, "turn 5")) return error.UnexpectedThirdTurn;

    return .{ .restored_messages = session.messages.len, .output = third.output };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const outcome = try run(arena.allocator());
    std.debug.print("restored messages: {d}\n", .{outcome.restored_messages});
    std.debug.print("output: {s}\n", .{outcome.output});
}
