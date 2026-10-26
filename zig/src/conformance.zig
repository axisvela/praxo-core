const std = @import("std");
const core = @import("core_conformance.zig");
const json = @import("json.zig");
const jsonschema = @import("jsonschema.zig");
const plugin = @import("plugin.zig");
const toolcall = @import("toolcall.zig");

const Allocator = std.mem.Allocator;

const CheckError = error{CheckFailed};

fn check(condition: bool) !void {
    if (!condition) return CheckError.CheckFailed;
}

fn runToolcall(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    const operation = json.string(input, "operation") orelse "";
    const content = json.string(input, "content") orelse "";
    if (std.mem.eql(u8, operation, "strip")) {
        const got = try toolcall.stripMarkup(allocator, content);
        try check(std.mem.eql(u8, got, json.string(expect, "text") orelse ""));
        return;
    }
    const call = try toolcall.parseToolCall(allocator, content);
    if (json.boolean(expect, "nil", false)) {
        try check(call == null);
        return;
    }
    try check(call != null);
    try check(std.mem.eql(u8, call.?.name, json.string(expect, "name") orelse ""));
    const expected = json.get(expect, "input") orelse json.Json{ .object = .empty };
    try check(json.equals(call.?.input, expected));
}

fn containsPath(errors: []const jsonschema.ValidationError, path: []const u8) bool {
    for (errors) |error_value| {
        if (std.mem.eql(u8, error_value.path, path)) return true;
    }
    return false;
}

fn runJsonschema(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    const errors = try jsonschema.validate(
        allocator,
        json.get(input, "schema") orelse json.Json{ .object = .empty },
        json.get(input, "data") orelse json.Json{ .null = {} },
    );
    try check((errors.len == 0) == json.boolean(expect, "valid", false));
    const expected = json.array(expect, "errorPaths");
    try check(expected.len == errors.len);
    for (expected) |item| {
        const path = switch (item) {
            .string => |text| text,
            else => continue,
        };
        try check(containsPath(errors, path));
    }
}

fn runPlugin(allocator: Allocator, input: json.Json, expect: json.Json) !void {
    const raw = json.string(input, "raw") orelse
        try json.stringify(allocator, json.get(input, "manifest") orelse json.Json{ .object = .empty });
    const manifest = plugin.parseManifest(allocator, raw) catch null;
    try check((manifest != null) == json.boolean(expect, "valid", false));
    if (manifest) |value| {
        if (json.string(expect, "id")) |id| try check(std.mem.eql(u8, value.id, id));
        if (json.string(expect, "kind")) |kind| try check(std.mem.eql(u8, value.kind, kind));
    }
}

fn runVector(allocator: Allocator, group: []const u8, vector: json.Json) !void {
    const input = json.get(vector, "input") orelse json.Json{ .object = .empty };
    const expect = json.get(vector, "expect") orelse json.Json{ .object = .empty };
    if (std.mem.eql(u8, group, "toolcall")) return runToolcall(allocator, input, expect);
    if (std.mem.eql(u8, group, "jsonschema")) return runJsonschema(allocator, input, expect);
    if (std.mem.eql(u8, group, "plugin")) return runPlugin(allocator, input, expect);
    return core.run(allocator, group, vector);
}

fn readSpec(allocator: Allocator, io: std.Io, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |error_value| {
        if (error_value != error.FileNotFound) return error_value;
        const alternate = try std.fmt.allocPrint(allocator, "../{s}", .{path});
        return std.Io.Dir.cwd().readFileAlloc(io, alternate, allocator, .limited(1024 * 1024));
    };
}

fn runFile(allocator: Allocator, io: std.Io, path: []const u8, group: []const u8, failures: *std.array_list.Managed([]const u8)) !void {
    const text = try readSpec(allocator, io, path);
    const file = try json.parse(allocator, text);
    if (!std.mem.eql(u8, json.string(file, "group") orelse "", group)) {
        try failures.append(try std.fmt.allocPrint(allocator, "{s}: group mismatch", .{group}));
    }
    for (json.array(file, "vectors")) |vector| {
        const id = json.string(vector, "id") orelse "";
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        runVector(arena.allocator(), group, vector) catch |error_value| {
            const detail = switch (error_value) {
                CheckError.CheckFailed => "check failed",
                error.UnknownGroup => "unknown group",
                else => @errorName(error_value),
            };
            try failures.append(try std.fmt.allocPrint(allocator, "{s}/{s}: {s}", .{ group, id, detail }));
        };
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();
    var failures = std.array_list.Managed([]const u8).init(allocator);
    try runFile(allocator, io, "spec/vectors/toolcall.json", "toolcall", &failures);
    try runFile(allocator, io, "spec/vectors/jsonschema.json", "jsonschema", &failures);
    try runFile(allocator, io, "spec/vectors/plugin.json", "plugin", &failures);
    try runFile(allocator, io, "spec/vectors/memory.json", "memory", &failures);
    try runFile(allocator, io, "spec/vectors/event.json", "event", &failures);
    try runFile(allocator, io, "spec/vectors/stream.json", "stream", &failures);
    try runFile(allocator, io, "spec/vectors/checkpoint.json", "checkpoint", &failures);
    try runFile(allocator, io, "spec/vectors/policy.json", "policy", &failures);
    try runFile(allocator, io, "spec/vectors/context.json", "context", &failures);
    try runFile(allocator, io, "spec/vectors/middleware.json", "middleware", &failures);
    try runFile(allocator, io, "spec/vectors/agent-loop.json", "agent-loop", &failures);
    if (failures.items.len == 0) {
        std.debug.print("all spec vectors passed\n", .{});
        return;
    }
    for (failures.items) |failure| std.debug.print("{s}\n", .{failure});
    std.process.exit(1);
}
