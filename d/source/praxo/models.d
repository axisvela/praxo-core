module praxo.models;

import praxo.json : JSONValue, JSONType;

enum string SYSTEM = "system";
enum string USER = "user";
enum string ASSISTANT = "assistant";
enum string TOOL = "tool";
immutable string[] streamKinds = ["values", "updates", "messages", "tasks", "debug", "checkpoint"];

struct ContentBlock {
    string type = "text";
    string text;
    string imageUrl;
    string data;
}

struct ToolCall {
    string id = "";
    string name = "";
    JSONValue arguments;
}

struct Message {
    string role;
    string content;
    ContentBlock[] contentBlocks;
    ToolCall[] toolCalls;
    string toolId;

    this(string role, string content = null, ContentBlock[] blocks = [], ToolCall[] calls = [], string toolId = null) {
        this.role = role;
        this.content = content;
        this.contentBlocks = blocks;
        this.toolCalls = calls;
        this.toolId = toolId;
    }

    static Message text(string role, string content) {
        return Message(role, content);
    }

    static Message assistant(string content, ToolCall[] calls = []) {
        return Message(ASSISTANT, content, [], calls);
    }

    static Message tool(string content, string toolId) {
        return Message(TOOL, content, [], [], toolId);
    }
}

struct ToolSpec {
    string name;
    string description = "";
    JSONValue parameters;
    string risk;

    this(string name, string description = "", JSONValue parameters = JSONValue.init, string risk = null) {
        this.name = name;
        this.description = description;
        this.parameters = parameters;
        this.risk = risk;
    }
}

struct Usage {
    long inputTokens = 0;
    long outputTokens = 0;
    long cachedTokens = 0;

    Usage plus(Usage other) {
        return Usage(inputTokens + other.inputTokens, outputTokens + other.outputTokens,
                     cachedTokens + other.cachedTokens);
    }
}

struct Request {
    Message[] messages;
    ToolSpec[] tools;
    string toolChoice;
    JSONValue responseFormat;
    double temperature = 0;
}

struct Response {
    Message message;
    Usage usage;
    string finishReason;
}

struct Session {
    string id;
    Message[] messages;

    this(string id, Message[] messages = []) {
        this.id = id;
        this.messages = messages;
    }
}

struct RunResult {
    string runId = "";
    string output = "";
    long steps = 0;
    Usage usage;
}

class MemoryRecord {
    string id = "";
    string frame = "";
    string content = "";
    string createdAt;

    this(string id = "", string frame = "", string content = "", string createdAt = null) {
        this.id = id;
        this.frame = frame;
        this.content = content;
        this.createdAt = createdAt;
    }
}

struct PathGrant {
    string root;
    string access = "read";

    this(string root, string access = "read") {
        this.root = root;
        this.access = access;
    }
}

struct Action {
    string kind;
    string sessionId;
    string toolName;
    JSONValue arguments;
}

struct Decision {
    bool allowed = false;
    string reason = "";
}

struct Event {
    string type;
    string sessionId;
    string runId;
    JSONValue data;
}

JSONValue messageWire(Message message) {
    JSONValue[string] result;
    result["role"] = JSONValue(message.role);
    if (message.content !is null) result["content"] = JSONValue(message.content);
    if (message.contentBlocks.length > 0) {
        JSONValue[] blocks;
        foreach (block; message.contentBlocks) {
            JSONValue[string] item;
            item["type"] = JSONValue(block.type);
            if (block.text !is null) item["text"] = JSONValue(block.text);
            if (block.imageUrl !is null) item["image_url"] = JSONValue(block.imageUrl);
            if (block.data !is null) item["data"] = JSONValue(block.data);
            blocks ~= JSONValue(item);
        }
        result["contentBlocks"] = JSONValue(blocks);
    }
    if (message.toolCalls.length > 0) {
        JSONValue[] calls;
        foreach (call; message.toolCalls) {
            JSONValue[string] item;
            item["id"] = JSONValue(call.id);
            item["name"] = JSONValue(call.name);
            item["arguments"] = call.arguments;
            calls ~= JSONValue(item);
        }
        result["toolCalls"] = JSONValue(calls);
    }
    if (message.toolId !is null) result["toolId"] = JSONValue(message.toolId);
    return JSONValue(result);
}

JSONValue eventWire(Event event) {
    JSONValue[string] result;
    result["type"] = JSONValue(event.type);
    result["sessionId"] = JSONValue(event.sessionId);
    if (event.runId !is null) result["runId"] = JSONValue(event.runId);
    if (event.data.type != JSONType.null_) result["data"] = event.data;
    return JSONValue(result);
}
