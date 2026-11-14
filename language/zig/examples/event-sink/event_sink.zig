const std = @import("std");
const models = @import("models");
const runtime = @import("runtime");

const Recording = struct {
    allocator: std.mem.Allocator,
    kinds: std.array_list.Managed([]const u8),

    fn emit(ptr: *anyopaque, event: models.Event) void {
        const self: *Recording = @ptrCast(@alignCast(ptr));
        self.kinds.append(event.type) catch {};
    }

    fn sink(self: *Recording) runtime.EventSink {
        return .{ .ptr = self, .emitFn = emit };
    }
};

fn isToolCall(_: *anyopaque, event: models.Event) bool {
    return std.mem.eql(u8, event.type, "tool.call");
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var all = Recording{ .allocator = allocator, .kinds = std.array_list.Managed([]const u8).init(allocator) };
    var tool = Recording{ .allocator = allocator, .kinds = std.array_list.Managed([]const u8).init(allocator) };
    var filtered = runtime.FilterSink.init(tool.sink(), @ptrCast(&tool), isToolCall);
    var sinks = [_]runtime.EventSink{ all.sink(), filtered.sink() };
    var multi = runtime.MultiSink.init(&sinks);
    const events = [_]models.Event{
        .{ .type = "run.started", .session_id = "s1" },
        .{ .type = "tool.call", .session_id = "s1" },
        .{ .type = "run.completed", .session_id = "s1" },
    };
    for (events) |event| multi.sink().emit(event);
    if (all.kinds.items.len != 3 or tool.kinds.items.len != 1) return error.EventMismatch;
    std.debug.print("Zig event sink example passed\n", .{});
}
