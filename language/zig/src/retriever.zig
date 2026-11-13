const std = @import("std");

const Allocator = std.mem.Allocator;

pub const RetrieverError = error{
    RetrieverInvalid,
};

pub const MetadataEntry = struct {
    key: []const u8,
    value: []const u8,
};

pub const Document = struct {
    id: []const u8 = "",
    content: []const u8 = "",
    metadata: []const MetadataEntry = &.{},
    score: f64 = 0,
};

pub const RetrieveFn = *const fn (
    ctx: *anyopaque,
    allocator: Allocator,
    query: []const u8,
    limit: i64,
) anyerror![]Document;

pub const Retriever = struct {
    ctx: *anyopaque,
    retrieveFn: RetrieveFn,

    pub fn retrieve(
        self: Retriever,
        allocator: Allocator,
        query: []const u8,
        limit: i64,
    ) ![]Document {
        if (limit < 0) return RetrieverError.RetrieverInvalid;
        return self.retrieveFn(self.ctx, allocator, query, limit);
    }
};

pub fn retrieveDocuments(
    allocator: Allocator,
    retriever: Retriever,
    query: []const u8,
    limit: i64,
) ![]Document {
    return retriever.retrieve(allocator, query, limit);
}

pub fn errorCode(error_value: anyerror) []const u8 {
    return switch (error_value) {
        RetrieverError.RetrieverInvalid => "RETRIEVER_INVALID",
        else => "",
    };
}
