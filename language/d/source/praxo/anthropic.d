module praxo.anthropic;

import std.json : JSONType, JSONValue;
import std.algorithm : sort, startsWith;
import std.string : splitLines, strip, stripRight;

import praxo.agent : Model, StreamingModel;
import praxo.errors : PraxoError;
import praxo.json : get, getString, getInt, getArray, parse, stringify;
import praxo.models;
import praxo.provider;

struct AnthropicStreamCall {
    string id;
    string name;
    string arguments;
}

class AnthropicModel : Model, StreamingModel {
    string baseUrl;
    string model;
    string apiKey;
    string apiVersion;
    int maxTokens;
    ProviderTransport transport;
    ProviderStreamTransport streamTransport;

    this(string model, string apiKey, string baseUrl = "https://api.anthropic.com",
         string apiVersion = "2023-06-01", int maxTokens = 1024,
         ProviderTransport transport = null,
         ProviderStreamTransport streamTransport = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.model = model;
        this.apiKey = apiKey;
        this.apiVersion = apiVersion;
        this.maxTokens = maxTokens;
        this.transport = transport;
        this.streamTransport = streamTransport;
    }

    Response generate(Request request) {
        if (apiKey is null || apiKey.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "anthropic: API key is required");
        }
        if (model.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "anthropic: model is required");
        }
        auto payload = buildPayload(request);
        auto path = "/v1/messages";
        auto data = transport is null ? defaultPost(path, payload) : transport(path, payload);
        return parseResponse(data);
    }

    JSONValue defaultPost(string path, JSONValue payload) {
        string[string] headers;
        headers["content-type"] = "application/json";
        headers["x-api-key"] = apiKey;
        headers["anthropic-version"] = apiVersion;
        return postJSON(baseUrl, path, payload, headers);
    }

    Response generateStream(Request request, void delegate(string) onDelta) {
        if (apiKey is null || apiKey.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "anthropic: API key is required");
        }
        if (model.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "anthropic: model is required");
        }
        auto payload = buildPayload(request, true);
        auto path = "/v1/messages";
        string text;
        if (streamTransport !is null) {
            text = streamTransport(path, payload);
        } else {
            string[string] headers;
            headers["content-type"] = "application/json";
            headers["accept"] = "text/event-stream";
            headers["x-api-key"] = apiKey;
            headers["anthropic-version"] = apiVersion;
            text = postText(baseUrl, path, payload, headers);
        }
        return parseStreamResponse(text, onDelta);
    }

    Response parseStreamResponse(string text, void delegate(string) onDelta) {
        string content;
        AnthropicStreamCall[int] calls;
        long inputTokens;
        long outputTokens;
        long cachedTokens;
        string stopReason;
        bool stopped;
        foreach (line; text.splitLines) {
            auto trimmed = line.strip();
            if (!trimmed.startsWith("data:")) continue;
            auto chunk = trimmed[5 .. $].strip();
            if (chunk.length == 0) continue;
            JSONValue event;
            try {
                event = parse(chunk);
            } catch (Exception) {
                throw new PraxoError("MODEL_STREAM", "anthropic: invalid stream chunk");
            }
            auto kind = getString(event, "type");
            if (kind is null) kind = "";
            switch (kind) {
                case "message_start":
                    auto message = get(event, "message");
                    auto usage = get(message, "usage");
                    inputTokens = getInt(usage, "input_tokens", inputTokens);
                    cachedTokens = getInt(usage, "cache_read_input_tokens", cachedTokens);
                    break;
                case "content_block_start":
                    auto index = cast(int) getInt(event, "index", 0);
                    auto block = get(event, "content_block");
                    if (getString(block, "type") == "tool_use") {
                        AnthropicStreamCall call;
                        auto id = getString(block, "id");
                        auto name = getString(block, "name");
                        call.id = id is null ? "" : id;
                        call.name = name is null ? "" : name;
                        calls[index] = call;
                    }
                    break;
                case "content_block_delta":
                    auto index = cast(int) getInt(event, "index", 0);
                    auto delta = get(event, "delta");
                    auto deltaType = getString(delta, "type");
                    if (deltaType == "text_delta") {
                        auto piece = getString(delta, "text");
                        if (piece !is null && piece.length > 0) {
                            content ~= piece;
                            onDelta(piece);
                        }
                    } else if (deltaType == "input_json_delta" && index in calls) {
                        auto partial = getString(delta, "partial_json");
                        if (partial !is null) calls[index].arguments ~= partial;
                    }
                    break;
                case "message_delta":
                    auto delta = get(event, "delta");
                    auto reason = getString(delta, "stop_reason");
                    if (reason !is null && reason.length > 0) stopReason = reason;
                    auto usage = get(event, "usage");
                    outputTokens = getInt(usage, "output_tokens", outputTokens);
                    break;
                case "message_stop":
                    stopped = true;
                    break;
                case "error":
                    throw new PraxoError("MODEL_STREAM", "anthropic: stream error");
                default:
                    break;
            }
        }
        if (!stopped && stopReason.length == 0) {
            throw new PraxoError("MODEL_STREAM",
                "anthropic: stream ended before completion");
        }
        auto indexes = calls.keys;
        indexes.sort;
        ToolCall[] toolCalls;
        foreach (index; indexes) {
            auto call = calls[index];
            if (call.name.length == 0) continue;
            JSONValue arguments = emptyObject();
            if (call.arguments.length > 0) {
                try {
                    arguments = parse(call.arguments);
                } catch (Exception) {
                    throw new PraxoError("PROVIDER_JSON",
                        "anthropic: invalid tool arguments");
                }
                if (arguments.type != JSONType.object) {
                    throw new PraxoError("PROVIDER_JSON",
                        "anthropic: invalid tool arguments");
                }
            }
            toolCalls ~= ToolCall(call.id, call.name, arguments);
        }
        return Response(Message.assistant(content, toolCalls),
            Usage(inputTokens, outputTokens, cachedTokens), stopReason);
    }

    JSONValue buildPayload(Request request, bool stream = false) {
        string[] system;
        JSONValue[] messages;
        JSONValue[] pending;
        void flush() {
            if (pending.length == 0) return;
            JSONValue[string] item;
            item["role"] = JSONValue("user");
            item["content"] = arrayOf(pending);
            messages ~= objectOf(item);
            pending = [];
        }
        foreach (message; request.messages) {
            if (message.role == SYSTEM) {
                if (message.content !is null && message.content.length > 0) {
                    system ~= message.content;
                }
                continue;
            }
            if (message.role == TOOL) {
                JSONValue[string] result;
                result["type"] = JSONValue("tool_result");
                result["tool_use_id"] = JSONValue(message.toolId is null ? "" : message.toolId);
                result["content"] = JSONValue(message.content is null ? "" : message.content);
                pending ~= objectOf(result);
                continue;
            }
            flush();
            auto content = messageContent(message);
            if (content.length > 0) {
                JSONValue[string] item;
                item["role"] = JSONValue(message.role);
                item["content"] = arrayOf(content);
                messages ~= objectOf(item);
            }
        }
        flush();
        JSONValue[string] payload;
        payload["model"] = JSONValue(model);
        payload["max_tokens"] = JSONValue(maxTokens);
        payload["messages"] = arrayOf(messages);
        if (system.length > 0) {
            string joined;
            foreach (index, value; system) {
                if (index > 0) joined ~= "\n\n";
                joined ~= value;
            }
            payload["system"] = JSONValue(joined);
        }
        if (request.tools.length > 0) {
            JSONValue[] tools;
            foreach (tool; request.tools) {
                JSONValue[string] entry;
                entry["name"] = JSONValue(tool.name);
                entry["description"] = JSONValue(tool.description);
                entry["input_schema"] = tool.parameters.type == JSONType.object
                    ? tool.parameters : objectOf(emptySchema());
                tools ~= objectOf(entry);
            }
            payload["tools"] = arrayOf(tools);
            auto choice = toolChoice(request.toolChoice);
            if (choice.type == JSONType.object) payload["tool_choice"] = choice;
        }
        if (request.temperature != 0) {
            payload["temperature"] = JSONValue(request.temperature);
        }
        if (stream) payload["stream"] = JSONValue(true);
        return objectOf(payload);
    }

    JSONValue[] messageContent(Message message) {
        JSONValue[] content;
        if (message.content !is null && message.content.length > 0) {
            JSONValue[string] text;
            text["type"] = JSONValue("text");
            text["text"] = JSONValue(message.content);
            content ~= objectOf(text);
        }
        foreach (block; message.contentBlocks) {
            if (block.type == "text" && block.text !is null && block.text.length > 0) {
                JSONValue[string] text;
                text["type"] = JSONValue("text");
                text["text"] = JSONValue(block.text);
                content ~= objectOf(text);
            }
        }
        foreach (call; message.toolCalls) {
            JSONValue[string] item;
            item["type"] = JSONValue("tool_use");
            item["id"] = JSONValue(call.id);
            item["name"] = JSONValue(call.name);
            item["input"] = call.arguments;
            content ~= objectOf(item);
        }
        return content;
    }

    JSONValue toolChoice(string choice) {
        JSONValue[string] value;
        if (choice == "auto") value["type"] = JSONValue("auto");
        else if (choice == "required") value["type"] = JSONValue("any");
        else if (choice == "none") value["type"] = JSONValue("none");
        else return JSONValue(null);
        return objectOf(value);
    }

    JSONValue[string] emptySchema() {
        JSONValue[string] schema;
        schema["type"] = JSONValue("object");
        schema["properties"] = emptyObject();
        return schema;
    }

    Response parseResponse(JSONValue data) {
        if (get(data, "error").type != JSONType.null_) {
            throw new PraxoError("PROVIDER_HTTP", "anthropic: provider error");
        }
        string text;
        ToolCall[] calls;
        foreach (block; getArray(data, "content")) {
            auto type = getString(block, "type");
            if (type == "text") {
                auto value = getString(block, "text");
                if (value !is null) text ~= value;
            } else if (type == "tool_use") {
                auto input = get(block, "input");
                calls ~= ToolCall(
                    getString(block, "id"),
                    getString(block, "name"),
                    input.type == JSONType.object ? input : emptyObject()
                );
            }
        }
        auto usage = get(data, "usage");
        return Response(
            Message.assistant(text, calls),
            Usage(getInt(usage, "input_tokens"), getInt(usage, "output_tokens"),
                  getInt(usage, "cache_read_input_tokens")),
            getString(data, "stop_reason")
        );
    }
}
