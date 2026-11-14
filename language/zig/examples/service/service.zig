const std = @import("std");

const Response = struct { status: u16, body: []const u8 };

fn handle(method: []const u8, path: []const u8, principal: []const u8, body: []const u8) Response {
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/healthz")) {
        return .{ .status = 200, .body = "{\"status\":\"ok\"}" };
    }
    if (!std.mem.eql(u8, method, "POST") or !std.mem.eql(u8, path, "/run")) {
        return .{ .status = 404, .body = "{\"error\":\"not found\"}" };
    }
    if (principal.len == 0) {
        return .{ .status = 401, .body = "{\"error\":\"missing X-Praxo-Principal\"}" };
    }
    if (std.mem.indexOf(u8, body, "\"prompt\"") == null) {
        return .{ .status = 400, .body = "{\"error\":\"prompt is required\"}" };
    }
    return .{ .status = 200, .body = "{\"output\":\"hello from the service\"}" };
}

pub fn main() !void {
    if (handle("GET", "/healthz", "", "").status != 200) return error.HealthFailed;
    if (handle("POST", "/run", "", "{\"prompt\":\"hi\"}").status != 401) return error.PrincipalAccepted;
    if (handle("POST", "/run", "user-1", "{\"prompt\":\"hi\"}").status != 200) return error.RunFailed;
    std.debug.print("Zig service example passed\n", .{});
}
