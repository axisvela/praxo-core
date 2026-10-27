const std = @import("std");
const json = @import("json.zig");

pub const PluginManifest = struct {
    schema_version: i64,
    id: []const u8,
    version: []const u8,
    kind: []const u8,
    entrypoint: json.Json,
    protocol: []const u8,
    capabilities: []const []const u8,
    permissions: json.Json,
    limits: json.Json,
    isolation: []const u8,
    health: json.Json,
};

pub const PluginError = error{InvalidManifest};

const Allocator = std.mem.Allocator;
const top_keys = [_][]const u8{
    "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
    "capabilities", "permissions", "limits", "isolation", "health",
    "signature", "sbom",
};
const entrypoint_keys = [_][]const u8{ "type", "command", "module", "image", "args", "dir" };
const permission_keys = [_][]const u8{ "filesystem", "network", "env" };
const limit_keys = [_][]const u8{ "memoryMB", "cpuMillis", "timeoutMs", "maxInflight" };
const health_keys = [_][]const u8{ "method", "intervalMs" };
const signature_keys = [_][]const u8{ "algorithm", "keyId" };
const kinds = [_][]const u8{
    "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
    "memory.provider.v1", "sandbox.provider.v1",
};

fn contains(values: []const []const u8, key: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, key)) return true;
    }
    return false;
}

fn checkKeys(value: json.Json, allowed: []const []const u8) !void {
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (!contains(allowed, entry.key_ptr.*)) return PluginError.InvalidManifest;
    }
}

fn asObject(value: ?json.Json) json.Json {
    return value orelse json.Json{ .object = .empty };
}

fn asString(value: ?json.Json) ![]const u8 {
    const node = value orelse return PluginError.InvalidManifest;
    return switch (node) {
        .string => |text| text,
        else => return PluginError.InvalidManifest,
    };
}

fn asInt(value: ?json.Json) !i64 {
    const node = value orelse return PluginError.InvalidManifest;
    return switch (node) {
        .integer => |number| number,
        .float => |number| if (@floor(number) == number) @intFromFloat(number) else return PluginError.InvalidManifest,
        else => return PluginError.InvalidManifest,
    };
}

fn textPresent(value: ?json.Json) bool {
    if (value) |node| {
        return switch (node) {
            .string => |text| text.len > 0,
            else => false,
        };
    }
    return false;
}

fn validId(id: []const u8) bool {
    var iterator = std.mem.splitScalar(u8, id, '.');
    var parts: usize = 0;
    while (iterator.next()) |part| {
        if (part.len == 0) return false;
        if (part[0] == '-' or part[part.len - 1] == '-') return false;
        for (part) |byte| {
            if (!(std.ascii.isLower(byte) or std.ascii.isDigit(byte) or byte == '-')) return false;
        }
        parts += 1;
    }
    return parts >= 2;
}

fn validNumeric(value: []const u8) bool {
    if (value.len == 0) return false;
    if (value.len > 1 and value[0] == '0') return false;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return false;
    return true;
}

fn validSuffix(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '.')) return false;
    }
    return true;
}

fn validSemver(version: []const u8) bool {
    var core_end = version.len;
    if (std.mem.indexOfScalar(u8, version, '+')) |index| {
        core_end = index;
        if (!validSuffix(version[index + 1 ..])) return false;
    }
    if (std.mem.indexOfScalar(u8, version[0..core_end], '-')) |index| {
        if (!validSuffix(version[index + 1 .. core_end])) return false;
        core_end = index;
    }
    var iterator = std.mem.splitScalar(u8, version[0..core_end], '.');
    var parts: usize = 0;
    while (iterator.next()) |part| : (parts += 1) {
        if (!validNumeric(part)) return false;
    }
    return parts == 3;
}

pub fn parseManifest(allocator: Allocator, raw: []const u8) !PluginManifest {
    if (std.mem.trim(u8, raw, " \t\r\n").len == 0) return PluginError.InvalidManifest;
    const root = json.parse(allocator, raw) catch return PluginError.InvalidManifest;
    if (root != .object) return PluginError.InvalidManifest;
    try checkKeys(root, &top_keys);
    const schema_version = try asInt(json.get(root, "schemaVersion"));
    if (schema_version != 1) return PluginError.InvalidManifest;
    const id = try asString(json.get(root, "id"));
    if (!validId(id)) return PluginError.InvalidManifest;
    const version = try asString(json.get(root, "version"));
    if (!validSemver(version)) return PluginError.InvalidManifest;
    const kind = try asString(json.get(root, "kind"));
    if (!contains(&kinds, kind)) return PluginError.InvalidManifest;
    const protocol = try asString(json.get(root, "protocol"));
    if (!std.mem.eql(u8, protocol, "jsonrpc-2")) return PluginError.InvalidManifest;
    const entrypoint = asObject(json.get(root, "entrypoint"));
    if (entrypoint != .object) return PluginError.InvalidManifest;
    try checkKeys(entrypoint, &entrypoint_keys);
    const entry_type = try asString(json.get(entrypoint, "type"));
    const required = if (std.mem.eql(u8, entry_type, "process")) "command"
        else if (std.mem.eql(u8, entry_type, "wasm")) "module"
        else if (std.mem.eql(u8, entry_type, "container")) "image"
        else return PluginError.InvalidManifest;
    if (!textPresent(json.get(entrypoint, required))) return PluginError.InvalidManifest;
    const isolation = try asString(json.get(root, "isolation"));
    if (!std.mem.eql(u8, isolation, entry_type)) return PluginError.InvalidManifest;

    const permissions = asObject(json.get(root, "permissions"));
    if (permissions != .object) return PluginError.InvalidManifest;
    try checkKeys(permissions, &permission_keys);
    const limits = asObject(json.get(root, "limits"));
    if (limits != .object) return PluginError.InvalidManifest;
    try checkKeys(limits, &limit_keys);
    var limit_iterator = limits.object.iterator();
    while (limit_iterator.next()) |entry| {
        if (try asInt(entry.value_ptr.*) < 0) return PluginError.InvalidManifest;
    }
    const health = asObject(json.get(root, "health"));
    if (health != .object) return PluginError.InvalidManifest;
    try checkKeys(health, &health_keys);
    if (json.get(root, "signature")) |signature| {
        if (signature != .object) return PluginError.InvalidManifest;
        try checkKeys(signature, &signature_keys);
        if (!textPresent(json.get(signature, "algorithm")) or
            !textPresent(json.get(signature, "keyId"))) return PluginError.InvalidManifest;
    }

    var capabilities = std.array_list.Managed([]const u8).init(allocator);
    if (json.get(root, "capabilities")) |raw_capabilities| {
        if (raw_capabilities != .array) return PluginError.InvalidManifest;
        for (raw_capabilities.array.items) |item| {
            const capability = try asString(item);
            if (capability.len == 0) return PluginError.InvalidManifest;
            for (capabilities.items) |existing| {
                if (std.mem.eql(u8, existing, capability)) return PluginError.InvalidManifest;
            }
            try capabilities.append(capability);
        }
    }
    return .{
        .schema_version = schema_version,
        .id = id,
        .version = version,
        .kind = kind,
        .entrypoint = entrypoint,
        .protocol = protocol,
        .capabilities = capabilities.items,
        .permissions = permissions,
        .limits = limits,
        .isolation = isolation,
        .health = health,
    };
}

test "zig plugin" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const manifest = try parseManifest(arena.allocator(),
        "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}");
    try std.testing.expectEqualStrings("com.example.echo", manifest.id);
}
