module praxo.runtime;

import std.algorithm : canFind, sort, startsWith;
import std.array : array, join;
import std.conv : to;
import std.string : strip, toLower, replace, split;
import praxo.errors : PraxoError;
import praxo.json;
import praxo.models;

interface EventSink {
    void emit(Event event);
}

class MultiSink : EventSink {
    EventSink[] sinks;

    this(EventSink[] sinks) {
        this.sinks = sinks;
    }

    void emit(Event event) {
        foreach (sink; sinks) sink.emit(event);
    }
}

class FilterSink : EventSink {
    EventSink sink;
    bool delegate(Event) predicate;

    this(EventSink sink, bool delegate(Event) predicate) {
        this.sink = sink;
        this.predicate = predicate;
    }

    void emit(Event event) {
        if (predicate(event)) sink.emit(event);
    }
}

class MemoryStore {
    private MemoryRecord[][string] records;
    private size_t sequence = 0;

    MemoryRecord put(string sessionId, MemoryRecord record) {
        if (record.id.length == 0) {
            record.id = "mem-" ~ sequence.to!string;
            sequence++;
        }
        if (record.createdAt is null) record.createdAt = sequence.to!string;
        records[sessionId] ~= record;
        return record;
    }

    MemoryRecord[] search(string sessionId, string query, long limit) {
        auto needle = query.strip().toLower();
        MemoryRecord[] matches;
        foreach (record; (sessionId in records) ? records[sessionId] : []) {
            if (needle.length == 0 || record.content.toLower().canFind(needle)) matches ~= record;
        }
        matches.sort!((a, b) => (a.createdAt is null ? "" : a.createdAt) > (b.createdAt is null ? "" : b.createdAt));
        if (limit > 0 && matches.length > limit) return matches[0 .. cast(size_t) limit];
        return matches;
    }
}

class CheckpointAllowlist {
    private string[] registered;

    void register(string payloadType) {
        if (payloadType.length == 0) throw new PraxoError("CHECKPOINT_ERROR", "checkpoint: type is required");
        if (!registered.canFind(payloadType)) registered ~= payloadType;
    }

    string marshal(string payloadType, JSONValue value) {
        if (!registered.canFind(payloadType)) {
            throw new PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED",
                "checkpoint: payload type not allowed: " ~ payloadType);
        }
        JSONValue[string] envelope;
        envelope["type"] = JSONValue(payloadType);
        envelope["data"] = value;
        return stringify(JSONValue(envelope));
    }

    JSONValue unmarshal(string data) {
        auto envelope = parse(data);
        if (envelope.type != JSONType.object) {
            throw new PraxoError("CHECKPOINT_ERROR", "checkpoint: envelope must be an object");
        }
        auto payloadType = getString(envelope, "type");
        if (payloadType is null) payloadType = "";
        if (!registered.canFind(payloadType)) {
            throw new PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED",
                "checkpoint: payload type not allowed: " ~ payloadType);
        }
        return get(envelope, "data");
    }
}

class PathChecker {
    private PathGrant[] grants;

    this(PathGrant[] grants) {
        foreach (grant; grants) this.grants ~= PathGrant(normalize(grant.root), grant.access);
    }

    Decision check(string target, string need) {
        if (!["read", "write", "readwrite"].canFind(need)) {
            throw new PraxoError("POLICY_ERROR", "policy: invalid access");
        }
        if (grants.length == 0) return Decision(false, "no allowed roots");
        auto resolved = normalize(target);
        bool matched = false;
        foreach (grant; grants) {
            if (!within(grant.root, resolved)) continue;
            matched = true;
            if (allows(grant.access, need)) return Decision(true, "path within root");
        }
        return Decision(false, matched ? "insufficient grant" : "outside roots");
    }

    bool allowed(string target, string need) {
        try {
            return check(target, need).allowed;
        } catch (PraxoError) {
            return false;
        }
    }
}

private string normalize(string value) {
    auto path = value;
    string prefix = "";
    if (path.length >= 3 && path[1] == ':' && (path[2] == '/' || path[2] == '\\')) {
        prefix = path[0 .. 2];
        path = path[2 .. $];
    } else if (path.length > 0 && (path[0] == '/' || path[0] == '\\')) {
        prefix = "/";
    }
    string[] parts;
    foreach (part; path.replace("\\", "/").split("/")) {
        if (part == "..") {
            if (parts.length > 0) parts = parts[0 .. $ - 1];
        } else if (part.length > 0 && part != ".") {
            parts ~= part;
        }
    }
    return (prefix ~ parts.join("/")).toLower();
}

private bool within(string root, string target) {
    return target == root || (target.length > root.length && target.startsWith(root ~ "/"));
}

private bool allows(string grant, string need) {
    if (need == "read") return grant == "read" || grant == "readwrite";
    if (need == "write") return grant == "write" || grant == "readwrite";
    return grant == "readwrite";
}

struct ContextBudget {
    long maxTokens;
    long keepRecent;
}

long estimateTokens(Message[] messages) {
    long total = 0;
    foreach (message; messages) {
        total += 4 + (message.content is null ? 0 : message.content.length / 4);
        total += message.toolId is null ? 0 : message.toolId.length / 4;
        foreach (block; message.contentBlocks) {
            total += 4 + (block.text is null ? 0 : block.text.length / 4);
            total += block.imageUrl is null ? 0 : block.imageUrl.length / 4;
            total += block.data is null ? 0 : block.data.length / 4;
        }
        foreach (call; message.toolCalls) {
            total += 4 + call.name.length / 4;
            total += stringify(call.arguments).length / 4;
        }
    }
    return total;
}

string truncateToTokens(string value, long tokens) {
    if (tokens <= 0) return "";
    auto limit = cast(size_t) (tokens * 4);
    if (value.length <= limit) return value;
    if (limit <= 16) return value[0 .. limit];
    return value[0 .. limit - 16] ~ "\n[truncated]";
}

struct CompactResult {
    Message[] messages;
    bool ok;
}

CompactResult compact(ContextBudget budget, Message[] messages) {
    if (budget.maxTokens <= 0 || estimateTokens(messages) <= budget.maxTokens) {
        return CompactResult(messages, true);
    }
    Message[] system;
    Message[] rest;
    foreach (message; messages) {
        if (message.role == SYSTEM) {
            if (message.content !is null && message.content.startsWith("[context compacted:")) continue;
            system ~= message;
        } else {
            rest ~= message;
        }
    }
    if (estimateTokens(system) > budget.maxTokens) {
        if (system.length == 0) return CompactResult([], false);
        system[0].content = truncateToTokens(system[0].content is null ? "" : system[0].content,
            budget.maxTokens - 4);
        system = system[0 .. 1];
        if (estimateTokens(system) > budget.maxTokens) return CompactResult([], false);
    }
    auto keep = budget.keepRecent > 0 ? cast(size_t) budget.keepRecent : 4;
    size_t start = rest.length > keep ? rest.length - keep : 0;
    while (start > 0 && rest[start].role == TOOL) start--;
    auto marker = Message.text(SYSTEM, "[context compacted: " ~ start.to!string ~ " older messages omitted]");
    Message[] kept = rest[start .. $];
    Message[] output = system;
    if (start > 0) output ~= marker;
    output ~= kept;
    while (estimateTokens(output) > budget.maxTokens && kept.length > 1) {
        if (kept[1].role == TOOL) break;
        kept = kept[1 .. $];
        output = system;
        if (start > 0) output ~= marker;
        output ~= kept;
    }
    return CompactResult(output, estimateTokens(output) <= budget.maxTokens);
}
