const std = @import("std");

fn authorize(tenant: []const u8, role: []const u8, active: bool, tool: []const u8, target: []const u8) bool {
    return active and std.mem.eql(u8, role, "operator") and
        std.mem.eql(u8, tenant, target) and std.mem.eql(u8, tool, "record");
}

pub fn main() !void {
    if (!authorize("acme", "operator", true, "record", "acme")) return error.OperatorDenied;
    if (authorize("acme", "viewer", true, "record", "acme")) return error.ViewerAllowed;
    if (authorize("acme", "operator", true, "record", "other")) return error.TenantMismatch;
    std.debug.print("Zig identity policy example passed\n", .{});
}
