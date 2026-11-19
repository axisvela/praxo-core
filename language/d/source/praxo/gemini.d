module praxo.gemini;

import std.array : split;
import std.conv : to;
import std.json : JSONType, JSONValue;
import std.string : startsWith, strip, stripRight;

import praxo.agent : Model, StreamingModel;
import praxo.errors : PraxoError;
import praxo.json : get, getString, getInt, getArray, parse;
import praxo.models;
import praxo.provider;

class GeminiModel : Model, StreamingModel {
    string baseUrl;
    string model;
    string apiKey;
    int maxOutputTokens;
    ProviderTransport transport;
    ProviderStreamTransport streamTransport;

    this(string model, string apiKey,
         string baseUrl = "https://generativelanguage.googleapis.com",
         int maxOutputTokens = 0, ProviderTransport transport = null,
         ProviderStreamTransport streamTransport = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.model = model;
        this.apiKey = apiKey;
        this.maxOutputTokens = maxOutputTokens;
        this.transport = transport;
        this.streamTransport = streamTransport;
    }

    Response generate(Request request) {
        if (apiKey is null || apiKey.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "gemini: API key is required");
        }
        if (model.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "gemini: model is required");
        }
        auto payload = buildPayload(request);
        auto path = "/v1beta/models/" ~ model ~ ":generateContent";
        auto data = transport is null ? defaultPost(path, payload) : transport(path, payload);
        return parseResponse(data);
    }

    Response generateStream(Request request, void delegate(string) onDelta) {
        if (apiKey is null || apiKey.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "gemini: API key is required");
        }
        if (model.length == 0) {
            throw new PraxoError("MODEL_CONFIG", "gemini: model is required");
        }
        auto payload = buildPayload(request);
        auto path = "/v1beta/models/" ~ model ~ ":streamGenerateContent?alt=sse";
        string text;
        if (streamTransport !is null) {
            text = streamTransport(path, payload);
        } else {
            string[string] headers;
            headers["content-type"] = "application/json";
            headers["accept"] = "text/event-stream";
            headers["x-goog-api-key"] = apiKey;
            text = postText(baseUrl, path, payload, headers);
        }
        return parseStreamResponse(text, onDelta);
    }

    Response parseStreamResponse(string text, void delegate(string) onDelta) {
        string content;
        ToolCall[] calls;
        long inputTokens;
        long outputTokens;
        long cachedTokens;
        string finishReason;
        foreach (raw; text.split("\n")) {
            auto line = raw.strip;
            if (!line.startsWith("data:")) continue;
            auto chunk = line[5 .. $].strip;
            if (chunk.length == 0 || chunk == "[DONE]") continue;
            JSONValue event;
            try {
                event = parse(chunk);
            } catch (Exception) {
                throw new PraxoError("MODEL_STREAM", "gemini: invalid stream chunk");
            }
            if (event.type != JSONType.object) continue;
            if (get(event, "error").type != JSONType.null_) {
                throw new PraxoError("MODEL_STREAM", "gemini: provider stream error");
            }
            auto usage = get(event, "usageMetadata");
            if (usage.type == JSONType.object) {
                inputTokens = getInt(usage, "promptTokenCount");
                outputTokens = getInt(usage, "candidatesTokenCount");
                cachedTokens = getInt(usage, "cachedContentTokenCount");
            }
            auto candidates = getArray(event, "candidates");
            if (candidates.length == 0) continue;
            auto candidate = candidates[0];
            auto reason = getString(candidate, "finishReason");
            if (reason !is null) finishReason = reason;
            foreach (part; getArray(get(candidate, "content"), "parts")) {
                auto piece = getString(part, "text");
                if (piece !is null && piece.length > 0) {
                    content ~= piece;
                    onDelta(piece);
                }
                auto call = get(part, "functionCall");
                if (call.type == JSONType.object) {
                    auto args = get(call, "args");
                    calls ~= ToolCall(
                        "call-" ~ (calls.length + 1).to!string,
                        getString(call, "name"),
                        args.type == JSONType.object ? args : emptyObject()
                    );
                }
            }
        }
        return Response(
            Message.assistant(content, calls),
            Usage(inputTokens, outputTokens, cachedTokens),
            finishReason
        );
    }

    JSONValue defaultPost(string path, JSONValue payload) {
        string[string] headers;
        headers["content-type"] = "application/json";
        headers["x-goog-api-key"] = apiKey;
        return postJSON(baseUrl, path, payload, headers);
    }

    JSONValue buildPayload(Request request) {
        JSONValue[] system;
        JSONValue[] contents;
        JSONValue[] pending;
        string[string] names;
        void flush() {
            if (pending.length == 0) return;
            JSONValue[string] item;
            item["role"] = JSONValue("user");
            item["parts"] = arrayOf(pending);
            contents ~= objectOf(item);
            pending = [];
        }
        foreach (message; request.messages) {
            if (message.role == SYSTEM) {
                if (message.content !is null && message.content.length > 0) {
                    JSONValue[string] part;
                    part["text"] = JSONValue(message.content);
                    system ~= objectOf(part);
                }
                continue;
            }
            if (message.role == TOOL) {
                auto id = message.toolId is null ? "" : message.toolId;
                auto name = id in names ? names[id] : (id.length > 0 ? id : "tool");
                JSONValue[string] response;
                response["result"] = JSONValue(message.content is null ? "" : message.content);
                JSONValue[string] fn;
                fn["name"] = JSONValue(name);
                fn["response"] = objectOf(response);
                JSONValue[string] part;
                part["functionResponse"] = objectOf(fn);
                pending ~= objectOf(part);
                continue;
            }
            flush();
            auto parts = messageParts(message);
            if (parts.length > 0) {
                JSONValue[string] item;
                item["role"] = JSONValue(message.role == ASSISTANT ? "model" : "user");
                item["parts"] = arrayOf(parts);
                contents ~= objectOf(item);
            }
            foreach (call; message.toolCalls) {
                if (call.id.length > 0 && call.name.length > 0) names[call.id] = call.name;
            }
        }
        flush();
        JSONValue[string] payload;
        payload["contents"] = arrayOf(contents);
        if (system.length > 0) {
            JSONValue[string] instruction;
            instruction["parts"] = arrayOf(system);
            payload["system_instruction"] = objectOf(instruction);
        }
        if (request.tools.length > 0) {
            JSONValue[] declarations;
            foreach (tool; request.tools) {
                JSONValue[string] entry;
                entry["name"] = JSONValue(tool.name);
                entry["description"] = JSONValue(tool.description);
                entry["parameters"] = tool.parameters.type == JSONType.object
                    ? tool.parameters : emptySchema();
                declarations ~= objectOf(entry);
            }
            JSONValue[string] group;
            group["functionDeclarations"] = arrayOf(declarations);
            JSONValue[string] calling;
            calling["mode"] = JSONValue(toolMode(request.toolChoice));
            JSONValue[string] config;
            config["functionCallingConfig"] = objectOf(calling);
            JSONValue[] tools;
            tools ~= objectOf(group);
            payload["tools"] = arrayOf(tools);
            payload["toolConfig"] = objectOf(config);
        }
        if (request.temperature != 0 || maxOutputTokens > 0) {
            JSONValue[string] generation;
            generation["temperature"] = JSONValue(request.temperature);
            generation["maxOutputTokens"] = JSONValue(maxOutputTokens);
            payload["generationConfig"] = objectOf(generation);
        }
        return objectOf(payload);
    }

    JSONValue[] messageParts(Message message) {
        JSONValue[] parts;
        if (message.content !is null && message.content.length > 0) {
            JSONValue[string] text;
            text["text"] = JSONValue(message.content);
            parts ~= objectOf(text);
        }
        foreach (block; message.contentBlocks) {
            if (block.type == "text" && block.text !is null && block.text.length > 0) {
                JSONValue[string] text;
                text["text"] = JSONValue(block.text);
                parts ~= objectOf(text);
            }
        }
        foreach (call; message.toolCalls) {
            JSONValue[string] fn;
            fn["name"] = JSONValue(call.name);
            fn["args"] = call.arguments;
            JSONValue[string] part;
            part["functionCall"] = objectOf(fn);
            parts ~= objectOf(part);
        }
        return parts;
    }

    string toolMode(string choice) {
        if (choice == "required") return "ANY";
        if (choice == "none") return "NONE";
        return "AUTO";
    }

    JSONValue emptySchema() {
        JSONValue[string] schema;
        schema["type"] = JSONValue("object");
        schema["properties"] = emptyObject();
        return objectOf(schema);
    }

    Response parseResponse(JSONValue data) {
        if (get(data, "error").type != JSONType.null_) {
            throw new PraxoError("PROVIDER_HTTP", "gemini: provider error");
        }
        auto candidates = getArray(data, "candidates");
        if (candidates.length == 0) {
            throw new PraxoError("PROVIDER_HTTP", "gemini: empty response");
        }
        auto candidate = candidates[0];
        string text;
        ToolCall[] calls;
        foreach (part; getArray(get(candidate, "content"), "parts")) {
            auto value = getString(part, "text");
            if (value !is null) text ~= value;
            auto call = get(part, "functionCall");
            if (call.type == JSONType.object) {
                auto args = get(call, "args");
                calls ~= ToolCall(
                    "call-" ~ (calls.length + 1).to!string,
                    getString(call, "name"),
                    args.type == JSONType.object ? args : emptyObject()
                );
            }
        }
        auto usage = get(data, "usageMetadata");
        return Response(
            Message.assistant(text, calls),
            Usage(getInt(usage, "promptTokenCount"), getInt(usage, "candidatesTokenCount"),
                  getInt(usage, "cachedContentTokenCount")),
            getString(candidate, "finishReason")
        );
    }
}
