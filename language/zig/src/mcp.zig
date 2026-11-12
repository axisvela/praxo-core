const std = @import("std");
const json = @import("json.zig");

const Allocator = std.mem.Allocator;

pub const McpError = error{
    McpClosed,
    McpTransport,
    McpProtocol,
    McpHandshake,
    McpPagination,
    McpDuplicateTool,
    McpToolError,
    McpRpc,
};

pub const Transport = struct {
    ctx: *anyopaque,
    requestFn: *const fn (
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
        timeout_ms: u64,
    ) anyerror!json.Json,
    notifyFn: *const fn (
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
    ) anyerror!void,
    closeFn: *const fn (ctx: *anyopaque) void,

    pub fn request(
        self: Transport,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
        timeout_ms: u64,
    ) !json.Json {
        return self.requestFn(self.ctx, allocator, method, params, timeout_ms);
    }

    pub fn notify(
        self: Transport,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
    ) !void {
        return self.notifyFn(self.ctx, allocator, method, params);
    }

    pub fn close(self: Transport) void {
        self.closeFn(self.ctx);
    }
};

pub const Client = struct {
    allocator: Allocator,
    transport: Transport,
    requested_version: []const u8,
    client_version: []const u8,
    timeout_ms: u64,
    protocol_version: []const u8 = "",
    server_info: json.Json = .{ .object = .empty },

    pub fn init(
        allocator: Allocator,
        transport: Transport,
        requested_version: []const u8,
        client_version: []const u8,
        timeout_ms: u64,
    ) Client {
        return .{
            .allocator = allocator,
            .transport = transport,
            .requested_version = requested_version,
            .client_version = client_version,
            .timeout_ms = timeout_ms,
        };
    }

    pub fn start(self: *Client) !void {
        if (self.protocol_version.len > 0) return;

        var params = std.json.ObjectMap.empty;
        try params.put(self.allocator, "protocolVersion", .{ .string = self.requested_version });
        try params.put(self.allocator, "capabilities", .{ .object = .empty });
        var client_info = std.json.ObjectMap.empty;
        try client_info.put(self.allocator, "name", .{ .string = "praxo-core" });
        try client_info.put(self.allocator, "version", .{ .string = self.client_version });
        try params.put(self.allocator, "clientInfo", .{ .object = client_info });

        const result = try self.transport.request(
            self.allocator,
            "initialize",
            .{ .object = params },
            self.timeout_ms,
        );
        const version = json.string(result, "protocolVersion") orelse {
            return McpError.McpHandshake;
        };
        if (version.len == 0) return McpError.McpHandshake;
        self.protocol_version = try self.allocator.dupe(u8, version);
        if (json.get(result, "serverInfo")) |info| self.server_info = info;
        try self.transport.notify(
            self.allocator,
            "notifications/initialized",
            .{ .object = .empty },
        );
    }

    pub fn listTools(self: *Client) ![]json.Json {
        try self.start();
        var tools = std.array_list.Managed(json.Json).init(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();
        var cursors = std.StringHashMap(void).init(self.allocator);
        defer cursors.deinit();
        var cursor: ?[]const u8 = null;

        while (true) {
            var params = std.json.ObjectMap.empty;
            if (cursor) |value| {
                try params.put(self.allocator, "cursor", .{ .string = value });
            }
            const result = try self.transport.request(
                self.allocator,
                "tools/list",
                .{ .object = params },
                self.timeout_ms,
            );
            for (json.array(result, "tools")) |item| {
                const name = json.string(item, "name") orelse {
                    return McpError.McpProtocol;
                };
                if (names.contains(name)) return McpError.McpDuplicateTool;
                try names.put(name, {});
                try tools.append(item);
            }
            const next = json.string(result, "nextCursor") orelse break;
            if (next.len == 0) break;
            if (cursors.contains(next)) return McpError.McpPagination;
            try cursors.put(next, {});
            cursor = next;
        }
        std.mem.sort(json.Json, tools.items, {}, lessTool);
        return tools.toOwnedSlice();
    }

    pub fn callTool(
        self: *Client,
        name: []const u8,
        arguments: json.Json,
    ) !json.Json {
        try self.start();
        var params = std.json.ObjectMap.empty;
        try params.put(self.allocator, "name", .{ .string = name });
        try params.put(self.allocator, "arguments", arguments);
        const result = try self.transport.request(
            self.allocator,
            "tools/call",
            .{ .object = params },
            self.timeout_ms,
        );
        if (json.boolean(result, "isError", false)) return McpError.McpToolError;
        if (json.get(result, "structuredContent")) |value| {
            if (value != .null) return value;
        }
        var texts = std.array_list.Managed(json.Json).init(self.allocator);
        for (json.array(result, "content")) |item| {
            if (json.string(item, "type")) |kind| {
                if (std.mem.eql(u8, kind, "text")) {
                    if (json.string(item, "text")) |text| {
                        try texts.append(.{ .string = text });
                    }
                }
            }
        }
        if (texts.items.len == 0) return .{ .null = {} };
        if (texts.items.len == 1) return texts.items[0];
        return .{ .array = texts };
    }

    pub fn close(self: *Client) void {
        self.transport.close();
        self.protocol_version = "";
    }
};

fn lessTool(_: void, left: json.Json, right: json.Json) bool {
    const left_name = json.string(left, "name") orelse "";
    const right_name = json.string(right, "name") orelse "";
    return std.mem.lessThan(u8, left_name, right_name);
}

pub const StdioTransport = struct {
    allocator: Allocator,
    argv: []const []const u8,
    child: ?std.process.Child = null,
    next_id: u64 = 0,
    closed: bool = false,

    pub fn init(allocator: Allocator, argv: []const []const u8) StdioTransport {
        return .{ .allocator = allocator, .argv = argv };
    }

    pub fn transport(self: *StdioTransport) Transport {
        return .{
            .ctx = self,
            .requestFn = request,
            .notifyFn = notify,
            .closeFn = close,
        };
    }

    fn ensureStarted(self: *StdioTransport) !void {
        if (self.child != null) return;
        self.child = try std.process.spawn(io(), .{
            .argv = self.argv,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = .ignore,
        });
    }

    fn request(
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
        timeout_ms: u64,
    ) anyerror!json.Json {
        _ = timeout_ms;
        const self: *StdioTransport = @ptrCast(@alignCast(ctx));
        try self.ensureStarted();
        self.next_id += 1;
        const id = self.next_id;
        var message = std.json.ObjectMap.empty;
        try message.put(allocator, "jsonrpc", .{ .string = "2.0" });
        try message.put(allocator, "id", .{ .integer = @intCast(id) });
        try message.put(allocator, "method", .{ .string = method });
        try message.put(allocator, "params", params);
        const line = try json.stringify(allocator, .{ .object = message });
        defer allocator.free(line);
        try writeLine(self, allocator, line);

        var read_buffer: [4096]u8 = undefined;
        var reader = self.child.?.stdout.?.reader(io(), &read_buffer);
        while (true) {
            const response_line = reader.takeDelimiterExclusive('\n') catch {
                return McpError.McpClosed;
            };
            const parsed = json.parse(allocator, response_line) catch {
                return McpError.McpProtocol;
            };
            if (json.integer(parsed, "id", -1) != id) continue;
            if (json.get(parsed, "error") != null) return McpError.McpRpc;
            return json.get(parsed, "result") orelse .{ .object = .empty };
        }
    }

    fn notify(
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
    ) anyerror!void {
        const self: *StdioTransport = @ptrCast(@alignCast(ctx));
        try self.ensureStarted();
        var message = std.json.ObjectMap.empty;
        try message.put(allocator, "jsonrpc", .{ .string = "2.0" });
        try message.put(allocator, "method", .{ .string = method });
        try message.put(allocator, "params", params);
        const line = try json.stringify(allocator, .{ .object = message });
        defer allocator.free(line);
        try writeLine(self, allocator, line);
    }

    fn writeLine(self: *StdioTransport, allocator: Allocator, line: []const u8) !void {
        _ = allocator;
        var write_buffer: [4096]u8 = undefined;
        var writer = self.child.?.stdin.?.writer(io(), &write_buffer);
        try writer.writeAll(line);
        try writer.writeAll("\n");
        try writer.flush();
    }

    fn close(ctx: *anyopaque) void {
        const self: *StdioTransport = @ptrCast(@alignCast(ctx));
        if (self.closed) return;
        self.closed = true;
        if (self.child) |*child| {
            child.kill(io());
            self.child = null;
        }
    }

    fn io() std.Io {
        return std.Io.Threaded.global_single_threaded.io();
    }
};

pub const HttpTransport = struct {
    allocator: Allocator,
    endpoint: []const u8,
    headers: []const []const u8 = &.{},
    protocol_version: []const u8 = "2025-03-26",
    session_id: []const u8 = "",
    next_id: u64 = 0,
    closed: bool = false,

    pub fn init(allocator: Allocator, endpoint: []const u8) !HttpTransport {
        const lower = endpoint;
        if (!std.mem.startsWith(u8, lower, "https://") and
            !std.mem.startsWith(u8, lower, "http://"))
        {
            return McpError.McpTransport;
        }
        if (std.mem.startsWith(u8, lower, "http://") and !loopback(endpoint)) {
            return McpError.McpTransport;
        }
        return .{ .allocator = allocator, .endpoint = endpoint };
    }

    pub fn transport(self: *HttpTransport) Transport {
        return .{
            .ctx = self,
            .requestFn = request,
            .notifyFn = notify,
            .closeFn = close,
        };
    }

    fn request(
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
        timeout_ms: u64,
    ) anyerror!json.Json {
        const self: *HttpTransport = @ptrCast(@alignCast(ctx));
        if (self.closed) return McpError.McpClosed;
        self.next_id += 1;
        var message = std.json.ObjectMap.empty;
        try message.put(allocator, "jsonrpc", .{ .string = "2.0" });
        try message.put(allocator, "id", .{ .integer = @intCast(self.next_id) });
        try message.put(allocator, "method", .{ .string = method });
        try message.put(allocator, "params", params);
        const response = try self.post(allocator, .{ .object = message }, timeout_ms);
        if (json.get(response, "error") != null) return McpError.McpRpc;
        return json.get(response, "result") orelse .{ .object = .empty };
    }

    fn notify(
        ctx: *anyopaque,
        allocator: Allocator,
        method: []const u8,
        params: json.Json,
    ) anyerror!void {
        const self: *HttpTransport = @ptrCast(@alignCast(ctx));
        if (self.closed) return;
        var message = std.json.ObjectMap.empty;
        try message.put(allocator, "jsonrpc", .{ .string = "2.0" });
        try message.put(allocator, "method", .{ .string = method });
        try message.put(allocator, "params", params);
        _ = self.post(allocator, .{ .object = message }, 30000) catch {};
    }

    fn post(
        self: *HttpTransport,
        allocator: Allocator,
        message: json.Json,
        timeout_ms: u64,
    ) !json.Json {
        const body = try json.stringify(allocator, message);
        defer allocator.free(body);
        var argv = std.array_list.Managed([]const u8).init(allocator);
        defer argv.deinit();
        try argv.appendSlice(&.{
            "curl", "-sS", "-X", "POST",
            "-H", "content-type: application/json",
            "-H", "accept: application/json, text/event-stream",
        });
        const protocol_header = try std.fmt.allocPrint(
            allocator, "mcp-protocol-version: {s}", .{self.protocol_version});
        defer allocator.free(protocol_header);
        try argv.appendSlice(&.{ "-H", protocol_header });
        if (self.session_id.len > 0) {
            const session_header = try std.fmt.allocPrint(
                allocator, "mcp-session-id: {s}", .{self.session_id});
            defer allocator.free(session_header);
            try argv.appendSlice(&.{ "-H", session_header });
        }
        for (self.headers) |header| try argv.appendSlice(&.{ "-H", header });
        try argv.appendSlice(&.{
            "--data-binary", body, "-D", "-", self.endpoint,
        });
        const result = std.process.run(allocator, std.Io.Threaded.global_single_threaded.io(), .{
            .argv = argv.items,
            .timeout = .{ .duration = .{ .nanoseconds = timeout_ms * std.time.ns_per_ms } },
        }) catch return McpError.McpTransport;
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        return self.parseResponse(allocator, result.stdout);
    }

    fn parseResponse(self: *HttpTransport, allocator: Allocator, output: []const u8) !json.Json {
        const separator = std.mem.indexOf(u8, output, "\r\n\r\n") orelse {
            return McpError.McpProtocol;
        };
        const head = output[0..separator];
        const body = output[separator + 4 ..];
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        const status_line = lines.next() orelse return McpError.McpProtocol;
        var parts = std.mem.splitScalar(u8, status_line, ' ');
        _ = parts.next();
        const status_text = parts.next() orelse return McpError.McpProtocol;
        const status = std.fmt.parseInt(u16, status_text, 10) catch {
            return McpError.McpProtocol;
        };
        var content_type: []const u8 = "";
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const key = std.mem.trim(u8, line[0..colon], " ");
            const value = std.mem.trim(u8, line[colon + 1 ..], " ");
            if (std.ascii.eqlIgnoreCase(key, "mcp-session-id") and value.len > 0) {
                self.session_id = try allocator.dupe(u8, value);
            }
            if (std.ascii.eqlIgnoreCase(key, "content-type")) content_type = value;
        }
        if (status == 202 or status == 204 or std.mem.trim(u8, body, " \r\n").len == 0) {
            return .{ .object = .empty };
        }
        if (status < 200 or status >= 300) return McpError.McpTransport;
        const decoded = if (std.ascii.indexOfIgnoreCase(content_type, "text/event-stream") != null)
            try parseSse(allocator, body)
        else
            json.parse(allocator, body) catch return McpError.McpProtocol;
        if (json.get(decoded, "result")) |result| {
            if (json.string(result, "protocolVersion")) |version| {
                if (version.len > 0) self.protocol_version = try allocator.dupe(u8, version);
            }
        }
        return decoded;
    }

    fn close(ctx: *anyopaque) void {
        const self: *HttpTransport = @ptrCast(@alignCast(ctx));
        if (self.closed) return;
        self.closed = true;
        if (self.session_id.len == 0) return;
        var argv = std.array_list.Managed([]const u8).init(self.allocator);
        defer argv.deinit();
        argv.appendSlice(&.{ "curl", "-sS", "-X", "DELETE" }) catch return;
        const session_header = std.fmt.allocPrint(
            self.allocator, "mcp-session-id: {s}", .{self.session_id}) catch return;
        defer self.allocator.free(session_header);
        argv.appendSlice(&.{ "-H", session_header, self.endpoint }) catch return;
        const result = std.process.run(
            self.allocator,
            std.Io.Threaded.global_single_threaded.io(),
            .{ .argv = argv.items },
        ) catch return;
        self.allocator.free(result.stdout);
        self.allocator.free(result.stderr);
    }

    fn loopback(endpoint: []const u8) bool {
        const start = (std.mem.indexOf(u8, endpoint, "://") orelse return false) + 3;
        var rest = endpoint[start..];
        if (std.mem.indexOfScalar(u8, rest, '/')) |slash| rest = rest[0..slash];
        if (std.mem.indexOfScalar(u8, rest, ':')) |colon| rest = rest[0..colon];
        if (std.ascii.eqlIgnoreCase(rest, "localhost")) return true;
        if (std.ascii.eqlIgnoreCase(rest, "127.0.0.1")) return true;
        if (std.mem.eql(u8, rest, "::1")) return true;
        return std.mem.startsWith(u8, rest, "127.");
    }
};

fn parseSse(allocator: Allocator, body: []const u8) !json.Json {
    var fallback: ?json.Json = null;
    var events = std.mem.splitSequence(u8, body, "\n\n");
    while (events.next()) |event| {
        var data = std.array_list.Managed(u8).init(allocator);
        defer data.deinit();
        var lines = std.mem.splitScalar(u8, event, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "data:")) {
                if (data.items.len > 0) try data.append('\n');
                try data.appendSlice(std.mem.trimLeft(u8, line[5..], " "));
            }
        }
        if (data.items.len == 0) continue;
        const decoded = json.parse(allocator, data.items) catch continue;
        if (json.get(decoded, "result") != null) return decoded;
        if (fallback == null) fallback = decoded;
    }
    return fallback orelse McpError.McpProtocol;
}
