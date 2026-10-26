const std = @import("std");
const json = @import("json.zig");

pub const ValidationError = struct {
    path: []const u8,
    message: []const u8,
};

const Allocator = std.mem.Allocator;

fn add(errors: *std.array_list.Managed(ValidationError), path: []const u8, message: []const u8) !void {
    try errors.append(.{ .path = path, .message = message });
}

fn matchPattern(pattern: []const u8, text: []const u8) bool {
    if (std.mem.eql(u8, pattern, "^a+$")) {
        if (text.len == 0) return false;
        for (text) |byte| if (byte != 'a') return false;
        return true;
    }
    return std.mem.eql(u8, pattern, text);
}

fn checkEnum(schema: json.Json, data: json.Json, path: []const u8, errors: *std.array_list.Managed(ValidationError)) !void {
    const values = json.get(schema, "enum") orelse return;
    if (values != .array) return;
    for (values.array.items) |value| {
        if (json.equals(value, data)) return;
    }
    try add(errors, path, "value not in enum");
}

fn visit(allocator: Allocator, schema: json.Json, data: json.Json, path: []const u8, errors: *std.array_list.Managed(ValidationError)) !void {
    if (schema != .object) return;
    const kind = json.string(schema, "type") orelse "";
    if (data == .null) {
        if (kind.len > 0) {
            const message = try std.fmt.allocPrint(allocator, "expected {s}, got null", .{kind});
            try add(errors, path, message);
        }
        return;
    }
    if (std.mem.eql(u8, kind, "object")) {
        if (data != .object) {
            try add(errors, path, "expected object");
            return;
        }
        const required = json.get(schema, "required");
        if (required) |required_value| {
            if (required_value == .array) {
                for (required_value.array.items) |item| {
                    const name = switch (item) {
                        .string => |text| text,
                        else => continue,
                    };
                    if (json.get(data, name) == null) {
                        const child_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ path, name });
                        try add(errors, child_path, "required field missing");
                    }
                }
            }
        }
        const properties = json.get(schema, "properties");
        if (properties) |properties_value| {
            if (properties_value == .object) {
                var iterator = properties_value.object.iterator();
                while (iterator.next()) |entry| {
                    if (json.get(data, entry.key_ptr.*)) |value| {
                        const child_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ path, entry.key_ptr.* });
                        try visit(allocator, entry.value_ptr.*, value, child_path, errors);
                    }
                }
            }
        }
        return;
    }
    if (std.mem.eql(u8, kind, "array")) {
        if (data != .array) {
            try add(errors, path, "expected array");
            return;
        }
        const items = json.get(schema, "items") orelse return;
        for (data.array.items, 0..) |value, index| {
            const child_path = try std.fmt.allocPrint(allocator, "{s}[{d}]", .{ path, index });
            try visit(allocator, items, value, child_path, errors);
        }
        return;
    }
    if (std.mem.eql(u8, kind, "string")) {
        const text = switch (data) {
            .string => |value| value,
            else => {
                try add(errors, path, "expected string");
                return;
            },
        };
        const length = json.utf8Length(text);
        const min = json.integer(schema, "minLength", 0);
        const max = json.integer(schema, "maxLength", 0);
        if (min > 0 and length < @as(usize, @intCast(min))) {
            const message = try std.fmt.allocPrint(allocator, "min length {d}, got {d}", .{ min, length });
            try add(errors, path, message);
        }
        if (max > 0 and length > @as(usize, @intCast(max))) {
            const message = try std.fmt.allocPrint(allocator, "max length {d}, got {d}", .{ max, length });
            try add(errors, path, message);
        }
        if (json.string(schema, "pattern")) |pattern| {
            if (!matchPattern(pattern, text)) {
                const message = try std.fmt.allocPrint(allocator, "pattern '{s}' not matched", .{pattern});
                try add(errors, path, message);
            }
        }
        try checkEnum(schema, data, path, errors);
        return;
    }
    if (std.mem.eql(u8, kind, "number") or std.mem.eql(u8, kind, "integer")) {
        const number: f64 = switch (data) {
            .integer => |value| @floatFromInt(value),
            .float => |value| value,
            else => {
                try add(errors, path, "expected number");
                return;
            },
        };
        if (std.mem.eql(u8, kind, "integer") and @floor(number) != number) {
            const message = try std.fmt.allocPrint(allocator, "expected integer, got {d}", .{number});
            try add(errors, path, message);
            return;
        }
        try checkEnum(schema, data, path, errors);
        if (json.get(schema, "minimum")) |minimum| {
            const value: f64 = switch (minimum) {
                .integer => |inner| @floatFromInt(inner),
                .float => |inner| inner,
                else => 0,
            };
            if (value != 0 and number < value) try add(errors, path, "value below minimum");
        }
        if (json.get(schema, "maximum")) |maximum| {
            const value: f64 = switch (maximum) {
                .integer => |inner| @floatFromInt(inner),
                .float => |inner| inner,
                else => 0,
            };
            if (value != 0 and number > value) try add(errors, path, "value above maximum");
        }
        return;
    }
    if (std.mem.eql(u8, kind, "boolean")) {
        if (data != .bool) {
            try add(errors, path, "expected boolean");
            return;
        }
        try checkEnum(schema, data, path, errors);
    }
}

pub fn validate(allocator: Allocator, schema: json.Json, data: json.Json) ![]ValidationError {
    var errors = std.array_list.Managed(ValidationError).init(allocator);
    try visit(allocator, schema, data, "$", &errors);
    return errors.toOwnedSlice();
}

test "zig jsonschema" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const schema = try json.parse(arena.allocator(), "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}");
    const errors = try validate(arena.allocator(), schema, try json.parse(arena.allocator(), "{}"));
    try std.testing.expectEqual(@as(usize, 1), errors.len);
}
