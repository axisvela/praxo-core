const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Principal = struct {
    subject: []const u8,
    tenant: []const u8,
    expires: i64,
};

pub const Response = struct {
    status: u16,
    body: []const u8,
};

pub const Transport = struct {
    ctx: *anyopaque,
    postFormFn: *const fn (ctx: *anyopaque, url: []const u8, form: []const u8, authorization: ?[]const u8) anyerror!Response,

    pub fn postForm(self: Transport, url: []const u8, form: []const u8, authorization: ?[]const u8) anyerror!Response {
        return self.postFormFn(self.ctx, url, form, authorization);
    }
};

pub const AuthError = error{
    InvalidToken,
    RevocationFailed,
};

pub const IntrospectionAuthenticator = struct {
    allocator: Allocator,
    transport: Transport,
    endpoint: []const u8,
    client_id: []const u8 = "",
    client_secret: []const u8 = "",
    tenant_claim: []const u8 = "tenant",

    pub fn init(
        allocator: Allocator,
        transport: Transport,
        endpoint: []const u8,
        client_id: []const u8,
        client_secret: []const u8,
        tenant_claim: []const u8,
    ) IntrospectionAuthenticator {
        return .{
            .allocator = allocator,
            .transport = transport,
            .endpoint = endpoint,
            .client_id = client_id,
            .client_secret = client_secret,
            .tenant_claim = if (tenant_claim.len == 0) "tenant" else tenant_claim,
        };
    }

    pub fn authenticate(self: *const IntrospectionAuthenticator, authorization: ?[]const u8, now: i64) ?Principal {
        const header = authorization orelse return null;
        if (!std.mem.startsWith(u8, header, "Bearer ")) return null;
        const token = std.mem.trim(u8, header["Bearer ".len..], " \t\r\n");
        if (token.len == 0) return null;
        const form = encodeIntrospectionForm(self.allocator, token, self.client_id, self.client_secret) catch return null;
        defer self.allocator.free(form);
        const basic = basicAuth(self.allocator, self.client_id, self.client_secret) catch return null;
        defer if (basic) |value| self.allocator.free(value);
        const response = self.transport.postForm(self.endpoint, form, basic) catch return null;
        if (response.status != 200) return null;
        return self.parsePrincipal(response.body, now) catch null;
    }

    fn parsePrincipal(self: *const IntrospectionAuthenticator, body: []const u8, now: i64) !?Principal {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch return null;
        defer parsed.deinit();
        const root = switch (parsed.value) {
            .object => |value| value,
            else => return null,
        };
        const active = root.get("active") orelse return null;
        switch (active) {
            .bool => |flag| if (!flag) return null,
            else => return null,
        }
        const subject_value = root.get("sub") orelse return null;
        const subject = switch (subject_value) {
            .string => |value| value,
            else => return null,
        };
        if (subject.len == 0) return null;
        const tenant_value = root.get(self.tenant_claim) orelse return null;
        const tenant = switch (tenant_value) {
            .string => |value| value,
            else => return null,
        };
        if (tenant.len == 0) return null;
        const expires_value = root.get("exp") orelse return null;
        const expires = switch (expires_value) {
            .integer => |value| value,
            else => return null,
        };
        if (expires <= now) return null;
        const subject_copy = try self.allocator.dupe(u8, subject);
        errdefer self.allocator.free(subject_copy);
        const tenant_copy = try self.allocator.dupe(u8, tenant);
        return .{
            .subject = subject_copy,
            .tenant = tenant_copy,
            .expires = expires,
        };
    }
};

pub const RevocationClient = struct {
    allocator: Allocator,
    transport: Transport,
    endpoint: []const u8,
    client_id: []const u8 = "",
    client_secret: []const u8 = "",

    pub fn init(
        allocator: Allocator,
        transport: Transport,
        endpoint: []const u8,
        client_id: []const u8,
        client_secret: []const u8,
    ) RevocationClient {
        return .{
            .allocator = allocator,
            .transport = transport,
            .endpoint = endpoint,
            .client_id = client_id,
            .client_secret = client_secret,
        };
    }

    pub fn revoke(self: *const RevocationClient, token: []const u8) !void {
        if (token.len == 0) return AuthError.InvalidToken;
        const form = encodeRevocationForm(self.allocator, token, self.client_id, self.client_secret) catch return AuthError.RevocationFailed;
        defer self.allocator.free(form);
        const basic = basicAuth(self.allocator, self.client_id, self.client_secret) catch return AuthError.RevocationFailed;
        defer if (basic) |value| self.allocator.free(value);
        const response = self.transport.postForm(self.endpoint, form, basic) catch return AuthError.RevocationFailed;
        if (response.status != 200) return AuthError.RevocationFailed;
    }
};

fn encodeIntrospectionForm(allocator: Allocator, token: []const u8, client_id: []const u8, client_secret: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice("token=");
    try appendEncoded(&out, token);
    try out.appendSlice("&client_id=");
    try appendEncoded(&out, client_id);
    try out.appendSlice("&client_secret=");
    try appendEncoded(&out, client_secret);
    return out.toOwnedSlice();
}

fn encodeRevocationForm(allocator: Allocator, token: []const u8, client_id: []const u8, client_secret: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice("token=");
    try appendEncoded(&out, token);
    try out.appendSlice("&token_type_hint=access_token");
    try out.appendSlice("&client_id=");
    try appendEncoded(&out, client_id);
    try out.appendSlice("&client_secret=");
    try appendEncoded(&out, client_secret);
    return out.toOwnedSlice();
}

fn appendEncoded(out: *std.array_list.Managed(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '.' or byte == '_' or byte == '~') {
            try out.append(byte);
        } else {
            try out.append('%');
            try out.append(hex[byte >> 4]);
            try out.append(hex[byte & 0x0f]);
        }
    }
}

fn basicAuth(allocator: Allocator, client_id: []const u8, client_secret: []const u8) !?[]u8 {
    if (client_id.len == 0) return null;
    const raw = try std.mem.concat(allocator, u8, &.{ client_id, ":", client_secret });
    defer allocator.free(raw);
    const encoder = &std.base64.standard.Encoder;
    const buffer = try allocator.alloc(u8, encoder.calcSize(raw.len));
    defer allocator.free(buffer);
    const encoded = encoder.encode(buffer, raw);
    return try std.mem.concat(allocator, u8, &.{ "Basic ", encoded });
}
