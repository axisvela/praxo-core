const std = @import("std");
const ids = @import("ids.zig");
const json = @import("json.zig");
const models = @import("models.zig");

pub const RuntimeError = error{ CheckpointError, CheckpointTypeNotAllowed, PolicyError };
const Allocator = std.mem.Allocator;

pub const EventSink = struct {
    ptr: *anyopaque,
    emitFn: *const fn (ptr: *anyopaque, event: models.Event) void,

    pub fn emit(self: EventSink, event: models.Event) void {
        self.emitFn(self.ptr, event);
    }
};

pub const MultiSink = struct {
    sinks: []const EventSink,

    pub fn init(sinks: []const EventSink) MultiSink {
        return .{ .sinks = sinks };
    }

    pub fn sink(self: *MultiSink) EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ptr: *anyopaque, event: models.Event) void {
        const self: *MultiSink = @ptrCast(@alignCast(ptr));
        for (self.sinks) |child| child.emit(event);
    }
};

pub const FilterSink = struct {
    sink_value: EventSink,
    predicate_ctx: *anyopaque,
    predicate: *const fn (ctx: *anyopaque, event: models.Event) bool,

    pub fn init(sink_value: EventSink, predicate_ctx: *anyopaque, predicate: *const fn (ctx: *anyopaque, event: models.Event) bool) FilterSink {
        return .{ .sink_value = sink_value, .predicate_ctx = predicate_ctx, .predicate = predicate };
    }

    pub fn sink(self: *FilterSink) EventSink {
        return .{ .ptr = self, .emitFn = emitFn };
    }

    fn emitFn(ptr: *anyopaque, event: models.Event) void {
        const self: *FilterSink = @ptrCast(@alignCast(ptr));
        if (self.predicate(self.predicate_ctx, event)) self.sink_value.emit(event);
    }
};

const StoredRecord = struct {
    session: []const u8,
    record: models.MemoryRecord,
};

pub const MemoryStore = struct {
    allocator: Allocator,
    records: std.array_list.Managed(StoredRecord),
    sequence: usize = 0,

    pub fn init(allocator: Allocator) MemoryStore {
        return .{ .allocator = allocator, .records = std.array_list.Managed(StoredRecord).init(allocator) };
    }

    pub fn put(self: *MemoryStore, session: []const u8, record: models.MemoryRecord) !models.MemoryRecord {
        var result = record;
        if (result.id.len == 0) {
            result.id = try std.fmt.allocPrint(self.allocator, "mem-{d}-{d}", .{ ids.next(), self.sequence });
            self.sequence += 1;
        }
        if (result.created_at == null) {
            result.created_at = try std.fmt.allocPrint(self.allocator, "{d}", .{ids.next()});
        }
        try self.records.append(.{ .session = session, .record = result });
        return result;
    }

    pub fn search(self: *MemoryStore, allocator: Allocator, session: []const u8, query: []const u8, limit: usize) ![]models.MemoryRecord {
        var matches = std.array_list.Managed(models.MemoryRecord).init(allocator);
        const needle = std.mem.trim(u8, query, " \t\r\n");
        for (self.records.items) |stored| {
            if (!std.mem.eql(u8, stored.session, session)) continue;
            if (needle.len == 0 or containsIgnoreCase(stored.record.content, needle)) {
                try matches.append(stored.record);
            }
        }
        std.mem.sort(models.MemoryRecord, matches.items, {}, lessByCreatedAt);
        if (limit > 0 and matches.items.len > limit) return matches.items[0..limit];
        return matches.toOwnedSlice();
    }
};

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        var equal = true;
        for (needle, 0..) |byte, offset| {
            if (std.ascii.toLower(haystack[index + offset]) != std.ascii.toLower(byte)) {
                equal = false;
                break;
            }
        }
        if (equal) return true;
    }
    return false;
}

fn lessByCreatedAt(_: void, left: models.MemoryRecord, right: models.MemoryRecord) bool {
    const a = left.created_at orelse "";
    const b = right.created_at orelse "";
    return std.mem.order(u8, a, b) == .gt;
}

pub const CheckpointAllowlist = struct {
    allocator: Allocator,
    registered: std.array_list.Managed([]const u8),

    pub fn init(allocator: Allocator) CheckpointAllowlist {
        return .{ .allocator = allocator, .registered = std.array_list.Managed([]const u8).init(allocator) };
    }

    pub fn register(self: *CheckpointAllowlist, payload_type: []const u8) !void {
        if (payload_type.len == 0) return RuntimeError.CheckpointError;
        for (self.registered.items) |existing| {
            if (std.mem.eql(u8, existing, payload_type)) return;
        }
        try self.registered.append(payload_type);
    }

    pub fn marshal(self: *CheckpointAllowlist, payload_type: []const u8, value: json.Json) ![]u8 {
        if (!self.isRegistered(payload_type)) return RuntimeError.CheckpointTypeNotAllowed;
        var object = std.json.ObjectMap.empty;
        try object.put(self.allocator, "type", .{ .string = payload_type });
        try object.put(self.allocator, "data", value);
        return json.stringify(self.allocator, .{ .object = object });
    }

    pub fn unmarshal(self: *CheckpointAllowlist, data: []const u8) !json.Json {
        const envelope = json.parse(self.allocator, data) catch return RuntimeError.CheckpointError;
        if (envelope != .object) return RuntimeError.CheckpointError;
        const payload_type = json.string(envelope, "type") orelse "";
        if (!self.isRegistered(payload_type)) return RuntimeError.CheckpointTypeNotAllowed;
        return json.get(envelope, "data") orelse json.Json{ .null = {} };
    }

    fn isRegistered(self: *CheckpointAllowlist, payload_type: []const u8) bool {
        for (self.registered.items) |existing| {
            if (std.mem.eql(u8, existing, payload_type)) return true;
        }
        return false;
    }
};

pub const PathChecker = struct {
    allocator: Allocator,
    grants: []models.PathGrant,

    pub fn init(allocator: Allocator, grants: []const models.PathGrant) !PathChecker {
        const normalized = try allocator.alloc(models.PathGrant, grants.len);
        for (grants, 0..) |grant, index| {
            normalized[index] = .{ .root = try normalize(allocator, grant.root), .access = grant.access };
        }
        return .{ .allocator = allocator, .grants = normalized };
    }

    pub fn check(self: *PathChecker, target: []const u8, need: []const u8) !models.Decision {
        if (!std.mem.eql(u8, need, "read") and !std.mem.eql(u8, need, "write") and !std.mem.eql(u8, need, "readwrite")) {
            return RuntimeError.PolicyError;
        }
        if (self.grants.len == 0) return .{ .allowed = false, .reason = "no allowed roots" };
        const resolved = try normalize(self.allocator, target);
        var matched = false;
        for (self.grants) |grant| {
            if (!within(grant.root, resolved)) continue;
            matched = true;
            if (allows(grant.access, need)) {
                return .{ .allowed = true, .reason = "path within root" };
            }
        }
        return .{ .allowed = false, .reason = if (matched) "insufficient grant" else "outside roots" };
    }

    pub fn allowed(self: *PathChecker, target: []const u8, need: []const u8) bool {
        const decision = self.check(target, need) catch return false;
        return decision.allowed;
    }
};

fn normalize(allocator: Allocator, value: []const u8) ![]u8 {
    var path = value;
    var prefix: []const u8 = "";
    if (path.len >= 3 and std.ascii.isAlphabetic(path[0]) and path[1] == ':' and (path[2] == '/' or path[2] == '\\')) {
        prefix = path[0..2];
        path = path[2..];
    } else if (path.len > 0 and (path[0] == '/' or path[0] == '\\')) {
        prefix = "/";
    }
    var parts = std.array_list.Managed([]const u8).init(allocator);
    var iterator = std.mem.tokenizeAny(u8, path, "/\\");
    while (iterator.next()) |part| {
        if (std.mem.eql(u8, part, "..")) {
            if (parts.items.len > 0) _ = parts.pop();
        } else if (!std.mem.eql(u8, part, ".")) {
            try parts.append(part);
        }
    }
    var out = std.array_list.Managed(u8).init(allocator);
    try out.appendSlice(prefix);
    for (parts.items, 0..) |part, index| {
        if (index > 0 or (prefix.len > 0 and !std.mem.eql(u8, prefix, "/"))) try out.append('/');
        try out.appendSlice(part);
    }
    if (out.items.len == 0) try out.append('.');
    if (@import("builtin").os.tag == .windows) {
        for (out.items) |*byte| byte.* = std.ascii.toLower(byte.*);
    }
    return out.toOwnedSlice();
}

fn within(root: []const u8, target: []const u8) bool {
    if (std.mem.eql(u8, root, target)) return true;
    if (target.len <= root.len) return false;
    if (!std.mem.eql(u8, target[0..root.len], root)) return false;
    return target[root.len] == '/';
}

fn allows(grant: []const u8, need: []const u8) bool {
    if (std.mem.eql(u8, need, "read")) return std.mem.eql(u8, grant, "read") or std.mem.eql(u8, grant, "readwrite");
    if (std.mem.eql(u8, need, "write")) return std.mem.eql(u8, grant, "write") or std.mem.eql(u8, grant, "readwrite");
    return std.mem.eql(u8, grant, "readwrite");
}

pub const ContextBudget = struct {
    max_tokens: i64,
    keep_recent: i64,
};

pub const CompactResult = struct {
    messages: []models.Message,
    ok: bool,
};

fn len(value: ?[]const u8) usize {
    return if (value) |text| text.len else 0;
}

pub fn estimateTokens(messages: []const models.Message) i64 {
    var total: i64 = 0;
    for (messages) |message| {
        total += 4 + @as(i64, @intCast(len(message.content) / 4));
        total += @as(i64, @intCast(len(message.tool_id) / 4));
        for (message.content_blocks) |block| {
            total += 4 + @as(i64, @intCast(len(block.text) / 4));
            total += @as(i64, @intCast(len(block.image_url) / 4));
            total += @as(i64, @intCast(len(block.data) / 4));
        }
        for (message.tool_calls) |call| {
            total += 4 + @as(i64, @intCast(call.name.len / 4));
            const encoded = json.stringify(std.heap.page_allocator, call.arguments) catch "";
            total += @as(i64, @intCast(encoded.len / 4));
        }
    }
    return total;
}

pub fn truncateToTokens(allocator: Allocator, value: []const u8, tokens: i64) ![]u8 {
    if (tokens <= 0) return "";
    const limit: usize = @intCast(tokens * 4);
    if (value.len <= limit) return allocator.dupe(u8, value);
    if (limit <= 16) return allocator.dupe(u8, value[0..limit]);
    return std.fmt.allocPrint(allocator, "{s}\n[truncated]", .{value[0 .. limit - 16]});
}

pub fn compact(allocator: Allocator, budget: ContextBudget, messages: []const models.Message) !CompactResult {
    if (budget.max_tokens <= 0 or estimateTokens(messages) <= budget.max_tokens) return .{ .messages = @constCast(messages), .ok = true };
    var system = std.array_list.Managed(models.Message).init(allocator);
    var rest = std.array_list.Managed(models.Message).init(allocator);
    for (messages) |message| {
        if (std.mem.eql(u8, message.role, models.SYSTEM)) {
            if (std.mem.startsWith(u8, message.content orelse "", "[context compacted:")) continue;
            try system.append(message);
        } else {
            try rest.append(message);
        }
    }
    if (estimateTokens(system.items) > budget.max_tokens) {
        if (system.items.len == 0) return .{ .messages = &.{}, .ok = false };
        var first = system.items[0];
        first.content = try truncateToTokens(allocator, first.content orelse "", budget.max_tokens - 4);
        system.clearRetainingCapacity();
        try system.append(first);
        if (estimateTokens(system.items) > budget.max_tokens) return .{ .messages = &.{}, .ok = false };
    }
    const keep: usize = @intCast(if (budget.keep_recent > 0) budget.keep_recent else 4);
    var start: usize = if (rest.items.len > keep) rest.items.len - keep else 0;
    while (start > 0 and std.mem.eql(u8, rest.items[start].role, models.TOOL)) start -= 1;
    const marker = models.Message{
        .role = models.SYSTEM,
        .content = try std.fmt.allocPrint(allocator, "[context compacted: {d} older messages omitted]", .{start}),
    };
    var kept = std.array_list.Managed(models.Message).init(allocator);
    for (rest.items[start..]) |message| try kept.append(message);
    var output = std.array_list.Managed(models.Message).init(allocator);
    for (system.items) |message| try output.append(message);
    if (start > 0) try output.append(marker);
    for (kept.items) |message| try output.append(message);
    while (estimateTokens(output.items) > budget.max_tokens and kept.items.len > 1) {
        if (std.mem.eql(u8, kept.items[1].role, models.TOOL)) break;
        _ = kept.orderedRemove(0);
        output.clearRetainingCapacity();
        for (system.items) |message| try output.append(message);
        if (start > 0) try output.append(marker);
        for (kept.items) |message| try output.append(message);
    }
    return .{ .messages = try output.toOwnedSlice(), .ok = estimateTokens(output.items) <= budget.max_tokens };
}
