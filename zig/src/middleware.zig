const std = @import("std");
const json = @import("json.zig");
const models = @import("models.zig");
const schema = @import("jsonschema.zig");

const Allocator = std.mem.Allocator;

pub const PiiRedactor = struct {
    pub fn redact(allocator: Allocator, text: []const u8) ![]u8 {
        var out = std.array_list.Managed(u8).init(allocator);
        var index: usize = 0;
        while (index < text.len) {
            if (text[index] != '@') {
                try out.append(text[index]);
                index += 1;
                continue;
            }
            var left = index;
            while (left > 0 and isLocalPart(text[left - 1])) left -= 1;
            var right = index + 1;
            while (right < text.len and isDomainPart(text[right])) right += 1;
            if (left < index and right > index + 1) {
                if (std.mem.indexOfScalar(u8, text[index + 1 .. right], '.')) |dot| {
                    const tld = text[index + 1 + dot + 1 .. right];
                    if (tld.len >= 2 and allLetters(tld)) {
                        const remove = index - left;
                        out.shrinkRetainingCapacity(out.items.len - remove);
                        try out.appendSlice("[REDACTED:email]");
                        index = right;
                        continue;
                    }
                }
            }
            try out.append('@');
            index += 1;
        }
        return out.toOwnedSlice();
    }

    fn isLocalPart(byte: u8) bool {
        return std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_' or byte == '%' or byte == '+' or byte == '-';
    }

    fn isDomainPart(byte: u8) bool {
        return std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '-';
    }

    fn allLetters(text: []const u8) bool {
        for (text) |byte| if (!std.ascii.isAlphabetic(byte)) return false;
        return true;
    }
};

pub const StructuredResult = struct {
    output: ?[]u8 = null,
    error_code: ?[]const u8 = null,
};

pub const StructuredOutput = struct {
    schema: json.Json,
    max_repairs: i64 = 0,
    repairer_ctx: ?*anyopaque = null,
    repairer: ?*const fn (ctx: ?*anyopaque, text: []const u8) ?[]const u8 = null,

    pub fn apply(self: StructuredOutput, allocator: Allocator, text: []const u8) !StructuredResult {
        var output = text;
        var attempt: i64 = 0;
        while (attempt <= self.max_repairs) : (attempt += 1) {
            if (extractJson(allocator, output)) |data| {
                if (schema.validate(allocator, self.schema, data) catch null) |errors| {
                    if (errors.len == 0) return .{ .output = try allocator.dupe(u8, output) };
                }
            }
            if (attempt == self.max_repairs and self.repairer == null) break;
            if (self.repairer) |repair| {
                const repaired = repair(self.repairer_ctx, output) orelse break;
                if (std.mem.trim(u8, repaired, " \t\r\n").len == 0) break;
                output = repaired;
            } else break;
        }
        return .{ .error_code = "AGENT_STRUCTURED_OUTPUT" };
    }
};

fn extractJson(allocator: Allocator, text: []const u8) ?json.Json {
    var value = std.mem.trim(u8, text, " \t\r\n");
    if (std.mem.startsWith(u8, value, "```")) {
        if (std.mem.indexOfScalar(u8, value, '\n')) |newline| value = value[newline + 1 ..];
        value = std.mem.trim(u8, std.mem.trimStart(u8, value, "`"), " \t\r\n`");
    }
    const object = std.mem.indexOfScalar(u8, value, '{');
    const array = std.mem.indexOfScalar(u8, value, '[');
    var start: ?usize = null;
    if (object != null and array != null) start = @min(object.?, array.?)
    else start = object orelse array;
    if (start == null) return null;
    return json.parse(allocator, value[start.?..]) catch null;
}

pub const CallLimit = struct {
    model_limit: i64,
    tool_limit: i64,
    models: i64 = 0,
    tools: i64 = 0,

    pub const Error = error{ AgentModelCallLimit, AgentToolCallLimit };

    pub fn beforeModel(self: *CallLimit) !void {
        self.models += 1;
        if (self.model_limit > 0 and self.models > self.model_limit) return Error.AgentModelCallLimit;
    }

    pub fn beforeTool(self: *CallLimit) !void {
        self.tools += 1;
        if (self.tool_limit > 0 and self.tools > self.tool_limit) return Error.AgentToolCallLimit;
    }
};

pub const ToolSelection = struct {
    selected: []const []const u8,

    pub fn init(selected: []const []const u8) ToolSelection {
        return .{ .selected = selected };
    }

    pub fn filter(self: ToolSelection, allocator: Allocator, tools: []const models.ToolSpec) ![]models.ToolSpec {
        var out = std.array_list.Managed(models.ToolSpec).init(allocator);
        for (tools) |tool| {
            if (self.contains(tool.name)) try out.append(tool);
        }
        return out.toOwnedSlice();
    }

    pub fn reject(self: ToolSelection, name: []const u8) !void {
        if (!self.contains(name)) return error.AgentToolNotSelected;
    }

    fn contains(self: ToolSelection, name: []const u8) bool {
        for (self.selected) |selected| {
            if (std.mem.eql(u8, selected, name)) return true;
        }
        return false;
    }
};

pub const Handler = struct {
    ctx: *anyopaque,
    callFn: *const fn (ctx: *anyopaque, request: models.Request) anyerror!models.Response,

    pub fn call(self: Handler, request: models.Request) !models.Response {
        return self.callFn(self.ctx, request);
    }
};

pub const Fallback = struct {
    next: Handler,
    fallback: Handler,

    pub fn handler(self: *Fallback) Handler {
        return .{ .ctx = self, .callFn = callFn };
    }

    fn callFn(ctx: *anyopaque, request: models.Request) anyerror!models.Response {
        const self: *Fallback = @ptrCast(@alignCast(ctx));
        return self.next.call(request) catch return self.fallback.call(request);
    }
};
