const std = @import("std");

pub const Json = std.json.Value;
pub const Allocator = std.mem.Allocator;

pub fn parse(allocator: Allocator, text: []const u8) !Json {
    const parsed = try std.json.parseFromSlice(Json, allocator, text, .{});
    return parsed.value;
}

pub fn stringify(allocator: Allocator, value: Json) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, value, .{});
}

pub fn get(node: Json, key: []const u8) ?Json {
    return switch (node) {
        .object => |map| map.get(key),
        else => null,
    };
}

pub fn has(node: Json, key: []const u8) bool {
    return get(node, key) != null;
}

pub fn string(node: Json, key: []const u8) ?[]const u8 {
    const value = get(node, key) orelse return null;
    return switch (value) {
        .string => |text| text,
        else => null,
    };
}

pub fn boolean(node: Json, key: []const u8, fallback: bool) bool {
    const value = get(node, key) orelse return fallback;
    return switch (value) {
        .bool => |flag| flag,
        else => fallback,
    };
}

pub fn integer(node: Json, key: []const u8, fallback: i64) i64 {
    const value = get(node, key) orelse return fallback;
    return switch (value) {
        .integer => |number| number,
        .float => |number| @intFromFloat(number),
        else => fallback,
    };
}

pub fn array(node: Json, key: []const u8) []const Json {
    const value = get(node, key) orelse return &.{};
    return switch (value) {
        .array => |items| items.items,
        else => &.{},
    };
}

pub fn object(node: Json, key: []const u8) ?std.json.ObjectMap {
    const value = get(node, key) orelse return null;
    return switch (value) {
        .object => |items| items,
        else => null,
    };
}

pub fn equals(left: Json, right: Json) bool {
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) {
        if (left == .integer and right == .float) return @as(f64, @floatFromInt(left.integer)) == right.float;
        if (left == .float and right == .integer) return left.float == @as(f64, @floatFromInt(right.integer));
        return false;
    }
    return switch (left) {
        .null => true,
        .bool => |value| value == right.bool,
        .integer => |value| value == right.integer,
        .float => |value| value == right.float,
        .number_string => |value| std.mem.eql(u8, value, right.number_string),
        .string => |value| std.mem.eql(u8, value, right.string),
        .array => |items| blk: {
            if (items.items.len != right.array.items.len) break :blk false;
            for (items.items, right.array.items) |a, b| {
                if (!equals(a, b)) break :blk false;
            }
            break :blk true;
        },
        .object => |items| blk: {
            if (items.count() != right.object.count()) break :blk false;
            var iterator = items.iterator();
            while (iterator.next()) |entry| {
                const other = right.object.get(entry.key_ptr.*) orelse break :blk false;
                if (!equals(entry.value_ptr.*, other)) break :blk false;
            }
            break :blk true;
        },
    };
}

pub fn utf8Length(text: []const u8) usize {
    var count: usize = 0;
    for (text) |byte| {
        if (byte & 0xC0 != 0x80) count += 1;
    }
    return count;
}
