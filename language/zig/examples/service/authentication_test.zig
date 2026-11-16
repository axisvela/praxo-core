const std = @import("std");
const service = @import("authentication.zig");

const now: i64 = 1_700_000_000;

const Fake = struct {
    allocator: std.mem.Allocator,
    status: u16 = 200,
    body: []const u8 = "",
    fail: bool = false,
    calls: usize = 0,
    last_url: []const u8 = "",
    last_form: []const u8 = "",
    last_auth: ?[]const u8 = null,

    fn postForm(
        ctx: *anyopaque,
        url: []const u8,
        form: []const u8,
        authorization: ?[]const u8,
    ) anyerror!service.Response {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        self.last_url = try self.allocator.dupe(u8, url);
        self.last_form = try self.allocator.dupe(u8, form);
        self.last_auth = if (authorization) |value| try self.allocator.dupe(u8, value) else null;
        if (self.fail) return error.Unavailable;
        return .{ .status = self.status, .body = self.body };
    }

    fn transport(self: *Fake) service.Transport {
        return .{ .ctx = self, .postFormFn = postForm };
    }
};

fn expectRejected(allocator: std.mem.Allocator, body: []const u8, status: u16, authorization: []const u8) !void {
    var fake = Fake{ .allocator = allocator, .status = status, .body = body };
    const authenticator = service.IntrospectionAuthenticator.init(
        allocator,
        fake.transport(),
        "https://idp.example/introspect",
        "",
        "",
        "tenant",
    );
    try std.testing.expect(authenticator.authenticate(authorization, now) == null);
}

test "introspection accepts an active bearer token" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{
        .allocator = allocator,
        .body = "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":1700000060}",
    };
    const authenticator = service.IntrospectionAuthenticator.init(
        allocator,
        fake.transport(),
        "https://id.example.com/introspect",
        "svc",
        "secret",
        "tenant",
    );
    const principal = authenticator.authenticate("Bearer opaque-token", now).?;
    try std.testing.expectEqualStrings("user-1", principal.subject);
    try std.testing.expectEqualStrings("tenant-a", principal.tenant);
    try std.testing.expectEqual(@as(i64, 1_700_000_060), principal.expires);
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqualStrings("https://id.example.com/introspect", fake.last_url);
    try std.testing.expect(std.mem.indexOf(u8, fake.last_form, "token=opaque-token") != null);
    try std.testing.expect(std.mem.indexOf(u8, fake.last_form, "client_id=svc") != null);
    try std.testing.expect(std.mem.indexOf(u8, fake.last_form, "client_secret=secret") != null);
    try std.testing.expectEqualStrings("Basic c3ZjOnNlY3JldA==", fake.last_auth.?);
}

test "introspection rejects missing scheme and empty token locally" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{
        .allocator = allocator,
        .body = "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":1700000060}",
    };
    const authenticator = service.IntrospectionAuthenticator.init(
        allocator,
        fake.transport(),
        "https://id.example.com/introspect",
        "svc",
        "secret",
        "tenant",
    );
    try std.testing.expect(authenticator.authenticate(null, now) == null);
    try std.testing.expect(authenticator.authenticate("Basic token", now) == null);
    try std.testing.expect(authenticator.authenticate("Bearer", now) == null);
    try std.testing.expect(authenticator.authenticate("Bearer   ", now) == null);
    try std.testing.expectEqual(@as(usize, 0), fake.calls);
}

test "introspection rejects invalid claims and malformed bodies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bodies = [_][]const u8{
        "{\"active\":false,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":1700000060}",
        "{\"active\":true,\"tenant\":\"tenant-a\",\"exp\":1700000060}",
        "{\"active\":true,\"sub\":\"\",\"tenant\":\"tenant-a\",\"exp\":1700000060}",
        "{\"active\":true,\"sub\":\"user-1\",\"exp\":1700000060}",
        "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"\",\"exp\":1700000060}",
        "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":1700000000}",
        "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\"}",
        "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":\"1700000060\"}",
        "not-json",
    };
    for (bodies) |body| {
        try expectRejected(allocator, body, 200, "Bearer token-1");
    }
}

test "introspection fails closed on non-200 and transport errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try expectRejected(
        allocator,
        "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\",\"exp\":1700000060}",
        500,
        "Bearer token-1",
    );
    var fake = Fake{ .allocator = allocator, .fail = true };
    const authenticator = service.IntrospectionAuthenticator.init(
        allocator,
        fake.transport(),
        "https://id.example.com/introspect",
        "",
        "",
        "tenant",
    );
    try std.testing.expect(authenticator.authenticate("Bearer token-1", now) == null);
}

test "introspection honors a custom tenant claim" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{
        .allocator = allocator,
        .body = "{\"active\":true,\"sub\":\"user-1\",\"org\":\"org-a\",\"exp\":1700000060}",
    };
    const authenticator = service.IntrospectionAuthenticator.init(
        allocator,
        fake.transport(),
        "https://id.example.com/introspect",
        "",
        "",
        "org",
    );
    const principal = authenticator.authenticate("Bearer token-1", now).?;
    try std.testing.expectEqualStrings("org-a", principal.tenant);
    try std.testing.expect(fake.last_auth == null);
}

test "revocation posts the access token hint" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fake = Fake{ .allocator = allocator };
    const client = service.RevocationClient.init(
        allocator,
        fake.transport(),
        "https://id.example.com/revoke",
        "svc",
        "secret",
    );
    try client.revoke("token-1");
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqualStrings("https://id.example.com/revoke", fake.last_url);
    try std.testing.expect(std.mem.indexOf(u8, fake.last_form, "token=token-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, fake.last_form, "token_type_hint=access_token") != null);
    try std.testing.expectEqualStrings("Basic c3ZjOnNlY3JldA==", fake.last_auth.?);
}

test "revocation fails closed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var denied = Fake{ .allocator = allocator, .status = 400 };
    const denied_client = service.RevocationClient.init(
        allocator,
        denied.transport(),
        "https://id.example.com/revoke",
        "",
        "",
    );
    try std.testing.expectError(service.AuthError.RevocationFailed, denied_client.revoke("token-1"));
    var broken = Fake{ .allocator = allocator, .fail = true };
    const broken_client = service.RevocationClient.init(
        allocator,
        broken.transport(),
        "https://id.example.com/revoke",
        "",
        "",
    );
    try std.testing.expectError(service.AuthError.RevocationFailed, broken_client.revoke("token-1"));
    var empty = Fake{ .allocator = allocator };
    const empty_client = service.RevocationClient.init(
        allocator,
        empty.transport(),
        "https://id.example.com/revoke",
        "",
        "",
    );
    try std.testing.expectError(service.AuthError.InvalidToken, empty_client.revoke(""));
    try std.testing.expectEqual(@as(usize, 0), empty.calls);
}
