const std = @import("std");

var counter = std.atomic.Value(u64).init(1);

pub fn next() u64 {
    return counter.fetchAdd(1, .monotonic);
}
