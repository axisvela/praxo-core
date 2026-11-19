const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

extern fn px_plugin_process_start_simple(
    plugin_id: [*:0]const u8,
    path: [*:0]const u8,
    arg: [*:0]const u8,
    token: [*:0]const u8,
    handle: *?*anyopaque,
    error_buffer: [*]u8,
    error_size: usize,
) c_int;
extern fn px_plugin_process_invoke_simple(
    handle: *anyopaque,
    service: [*:0]const u8,
    method: [*:0]const u8,
    payload: [*:0]const u8,
    response: [*]u8,
    response_size: usize,
    error_buffer: [*]u8,
    error_size: usize,
) c_int;
extern fn px_plugin_process_stop_simple(handle: *anyopaque) void;

pub const PluginProcessError = error{
    PluginStart,
    PluginInvoke,
};

pub const Host = struct {
    handle: *anyopaque,

    pub fn stop(self: *Host) void {
        px_plugin_process_stop_simple(self.handle);
        self.handle = undefined;
    }
};

pub fn start(
    allocator: Allocator,
    plugin_id: []const u8,
    path: []const u8,
    arg: []const u8,
    token: []const u8,
) !Host {
    const id = try allocator.dupeSentinel(u8, plugin_id, 0);
    defer allocator.free(id);
    const path_z = try allocator.dupeSentinel(u8, path, 0);
    defer allocator.free(path_z);
    const arg_z = try allocator.dupeSentinel(u8, arg, 0);
    defer allocator.free(arg_z);
    const token_z = try allocator.dupeSentinel(u8, token, 0);
    defer allocator.free(token_z);
    var handle: ?*anyopaque = null;
    var error_buffer: [256]u8 = undefined;
    error_buffer[0] = 0;
    const ok = px_plugin_process_start_simple(
        id.ptr,
        path_z.ptr,
        arg_z.ptr,
        token_z.ptr,
        &handle,
        error_buffer[0..].ptr,
        error_buffer.len,
    );
    if (ok == 0 or handle == null) return PluginProcessError.PluginStart;
    return .{ .handle = handle.? };
}

pub fn invoke(
    allocator: Allocator,
    host: *const Host,
    service: []const u8,
    method: []const u8,
    payload: []const u8,
) ![]u8 {
    const service_z = try allocator.dupeSentinel(u8, service, 0);
    defer allocator.free(service_z);
    const method_z = try allocator.dupeSentinel(u8, method, 0);
    defer allocator.free(method_z);
    const payload_z = try allocator.dupeSentinel(u8, payload, 0);
    defer allocator.free(payload_z);
    var response: [8192]u8 = undefined;
    response[0] = 0;
    var error_buffer: [256]u8 = undefined;
    error_buffer[0] = 0;
    const ok = px_plugin_process_invoke_simple(
        host.handle,
        service_z.ptr,
        method_z.ptr,
        payload_z.ptr,
        response[0..].ptr,
        response.len,
        error_buffer[0..].ptr,
        error_buffer.len,
    );
    if (ok == 0) return PluginProcessError.PluginInvoke;
    const length = std.mem.indexOfScalar(u8, response[0..], 0) orelse response.len;
    return allocator.dupe(u8, response[0..length]);
}

test "process plugin host echo" {
    const allocator = std.testing.allocator;
    const python = if (builtin.os.tag == .windows)
        "C:\\Python314\\python.exe"
    else
        "python3";
    var host = try start(
        allocator,
        "com.example.echo",
        python,
        "tests/fixtures/process_plugin.py",
        "",
    );
    defer host.stop();
    const response = try invoke(
        allocator,
        &host,
        "tool.provider",
        "echo",
        "{\"text\":\"hi\"}",
    );
    defer allocator.free(response);
    try std.testing.expectEqualStrings("{\"text\":\"hi\"}", response);
}
