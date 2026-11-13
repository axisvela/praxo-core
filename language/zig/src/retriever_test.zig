const std = @import("std");
const retriever = @import("retriever.zig");

const Fake = struct {
    fn retrieve(
        ctx: *anyopaque,
        allocator: std.mem.Allocator,
        query: []const u8,
        limit: i64,
    ) anyerror![]retriever.Document {
        _ = ctx;
        const documents = try allocator.alloc(retriever.Document, 1);
        documents[0] = .{
            .id = "doc-1",
            .content = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ query, limit }),
        };
        return documents;
    }
};

test "retriever passes query and limit to the function seam" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var context: u8 = 0;
    const seam = retriever.Retriever{ .ctx = &context, .retrieveFn = Fake.retrieve };

    const documents = try seam.retrieve(allocator, "hello", 3);
    try std.testing.expectEqual(@as(usize, 1), documents.len);
    try std.testing.expectEqualStrings("doc-1", documents[0].id);
    try std.testing.expectEqualStrings("hello:3", documents[0].content);

    const through_helper = try retriever.retrieveDocuments(allocator, seam, "hello", 2);
    try std.testing.expectEqualStrings("hello:2", through_helper[0].content);
}

test "retriever rejects a negative limit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var context: u8 = 0;
    const seam = retriever.Retriever{ .ctx = &context, .retrieveFn = Fake.retrieve };
    try std.testing.expectError(
        retriever.RetrieverError.RetrieverInvalid,
        seam.retrieve(allocator, "hello", -1),
    );
    try std.testing.expectEqualStrings(
        "RETRIEVER_INVALID",
        retriever.errorCode(retriever.RetrieverError.RetrieverInvalid),
    );
}
