const std = @import("std");
const json = @import("json");
const jsonschema = @import("jsonschema");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const schema = try json.parse(allocator, "{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}");
    const valid = try json.parse(allocator, "{\"name\":\"ok\"}");
    const invalid = try json.parse(allocator, "{}");
    const valid_errors = try jsonschema.validate(allocator, schema, valid);
    const invalid_errors = try jsonschema.validate(allocator, schema, invalid);
    if (valid_errors.len != 0 or invalid_errors.len == 0) return error.SchemaMismatch;
    std.debug.print("Zig structured output example passed\n", .{});
}
