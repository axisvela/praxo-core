module praxo.openai_compatible;

import std.json : JSONType, JSONValue;
import std.algorithm : sort, startsWith;
import std.string : splitLines, strip, stripRight;

import praxo.agent : Model, StreamingModel;
import praxo.errors : PraxoError;
import praxo.json : get, getString, getInt, getArray, parse, stringify;
import praxo.models;
import praxo.provider;

struct PartialCall {
    string id;
    string name;
    string arguments;
}

class OpenAICompatibleModel : Model, StreamingModel {
    string baseUrl;
    string model;
    string apiKey;
    ProviderTransport transport;
    ProviderStreamTransport streamTransport;

    this(string baseUrl, string model, string apiKey = null,
         ProviderTransport transport = null,
         ProviderStreamTransport streamTransport = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.model = model;
        this.apiKey = apiKey;
        this.transport = transport;
        this.streamTransport = streamTransport;
    }

    Response generate(Request request) {
        if (baseUrl.length == 0) {
            throw new PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        auto payload = buildPayload(request);
        auto path = "/chat/completions";
        auto data = transport is null ? defaultPost(path, payload) : transport(path, payload);
        return parseResponse(data);
    }

    Response generateStream(Request request, void delegate(string) onDelta) {
        if (baseUrl.length == 0) {
            throw new PraxoError("PROVIDER_HTTP", "provider base URL is required");
        }
        auto payload = buildPayload(request);
        payload.object["stream"] = JSONValue(true);
        auto path = "/chat/completions";
        string text;
        if (streamTransport !is null) {
            text = streamTransport(path, payload);
        } else {
            string[string] headers;
            headers["content-type"] = "application/json";
            headers["accept"] = "text/event-stream";
            if (apiKey !is null && apiKey.length > 0) {
                headers["authorization"] = "Bearer " ~ apiKey;
            }
            text = postText(baseUrl, path, payload, headers);
        }
        return parseStreamResponse(text, onDelta);
    }

    Response parseStreamResponse(string text, void delegate(string) onDelta) {
        string content;
        PartialCall[int] calls;
        long inputTokens;
        long outputTokens;
        string finishReason;
        bool done;
        foreach (line; text.splitLines) {
            auto trimmed = line.strip();
            if (!trimmed.startsWith("data:")) continue;
            auto chunk = trimmed[5 .. $].strip();
            if (chunk.length == 0) continue;
            if (chunk == "[DONE]") {
                done = true;
                break;
            }
            JSONValue event;
            try {
                event = parse(chunk);
            } catch (Exception) {
                throw new PraxoError("MODEL_STREAM", "invalid SSE packet");
            }
            auto usage = get(event, "usage");
            if (usage.type == JSONType.object) {
                inputTokens = getInt(usage, "prompt_tokens", inputTokens);
                outputTokens = getInt(usage, "completion_tokens", outputTokens);
            }
            foreach (choice; getArray(event, "choices")) {
                auto delta = get(choice, "delta");
                auto piece = getString(delta, "content");
                if (piece !is null && piece.length > 0) {
                    content ~= piece;
                    onDelta(piece);
                }
                foreach (item; getArray(delta, "tool_calls")) {
                    auto index = cast(int) getInt(item, "index", calls.length);
                    if (index < 0 || index >= 64) {
                        throw new PraxoError("PROVIDER_JSON", "tool call index out of range");
                    }
                    PartialCall slot = index in calls ? calls[index] : PartialCall();
                    slot.id ~= getString(item, "id");
                    auto toolFunction = get(item, "function");
                    slot.name ~= getString(toolFunction, "name");
                    slot.arguments ~= getString(toolFunction, "arguments");
                    calls[index] = slot;
                }
                auto reason = getString(choice, "finish_reason");
                if (reason !is null && reason.length > 0) {
                    finishReason = reason;
                    done = true;
                }
            }
        }
        if (!done) {
            throw new PraxoError("MODEL_STREAM", "stream ended before completion");
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
                    throw new PraxoError("PROVIDER_JSON", "invalid tool call arguments");
                }
                if (arguments.type != JSONType.object) {
                    throw new PraxoError("PROVIDER_JSON", "tool arguments must be an object");
                }
            }
            toolCalls ~= ToolCall(call.id, call.name, arguments);
        }
        return Response(Message.assistant(content, toolCalls),
            Usage(inputTokens, outputTokens), finishReason);
    }

    JSONValue defaultPost(string path, JSONValue payload) {
        string[string] headers;
        headers["content-type"] = "application/json";
        if (apiKey !is null && apiKey.length > 0) {
            headers["authorization"] = "Bearer " ~ apiKey;
        }
        return postJSON(baseUrl, path, payload, headers);
    }

    JSONValue buildPayload(Request request) {
        JSONValue[] messages;
        foreach (message; request.messages) {
            JSONValue[string] item;
            item["role"] = JSONValue(message.role);
            auto content = messageContent(message);
            item["content"] = JSONValue(content);
            if (message.role == ASSISTANT && message.toolCalls.length > 0) {
                JSONValue[] calls;
                foreach (call; message.toolCalls) {
                    JSONValue[string] toolFunction;
                    toolFunction["name"] = JSONValue(call.name);
                    toolFunction["arguments"] = JSONValue(stringify(call.arguments));
                    JSONValue[string] entry;
                    entry["id"] = JSONValue(call.id);
                    entry["type"] = JSONValue("function");
                    entry["function"] = objectOf(toolFunction);
                    calls ~= objectOf(entry);
                }
                item["tool_calls"] = arrayOf(calls);
            }
            if (message.role == TOOL && message.toolId !is null) {
                item["tool_call_id"] = JSONValue(message.toolId);
            }
            messages ~= objectOf(item);
        }
        JSONValue[string] payload;
        payload["model"] = JSONValue(model);
        payload["messages"] = arrayOf(messages);
        if (request.tools.length > 0) {
            JSONValue[] tools;
            foreach (tool; request.tools) {
                JSONValue[string] toolFunction;
                toolFunction["name"] = JSONValue(tool.name);
                toolFunction["description"] = JSONValue(tool.description);
                auto parameters = tool.parameters;
                if (parameters.type != JSONType.object) {
                    JSONValue[string] fallback;
                    fallback["type"] = JSONValue("object");
                    parameters = objectOf(fallback);
                }
                toolFunction["parameters"] = parameters;
                JSONValue[string] item;
                item["type"] = JSONValue("function");
                item["function"] = objectOf(toolFunction);
                tools ~= objectOf(item);
            }
            payload["tools"] = arrayOf(tools);
        }
        if (request.toolChoice !is null) {
            payload["tool_choice"] = JSONValue(request.toolChoice);
        }
        if (request.temperature != 0) {
            payload["temperature"] = JSONValue(request.temperature);
        }
        return objectOf(payload);
    }

    string messageContent(Message message) {
        if (message.content !is null && message.content.length > 0) {
            return message.content;
        }
        string content;
        foreach (block; message.contentBlocks) {
            if (block.type == "text" && block.text !is null) content ~= block.text;
        }
        return content;
    }

    Response parseResponse(JSONValue data) {
        auto choices = getArray(data, "choices");
        if (choices.length == 0) {
            throw new PraxoError("PROVIDER_RESPONSE", "provider response has no choices");
        }
        auto choice = choices[0];
        auto message = get(choice, "message");
        ToolCall[] calls;
        foreach (item; getArray(message, "tool_calls")) {
            auto toolFunction = get(item, "function");
            auto raw = getString(toolFunction, "arguments");
            JSONValue arguments;
            if (raw !is null && raw.length > 0) {
                arguments = parse(raw);
            } else {
                arguments = emptyObject();
            }
            calls ~= ToolCall(getString(item, "id"), getString(toolFunction, "name"), arguments);
        }
        auto usage = get(data, "usage");
        auto response = Response(
            Message.assistant(getString(message, "content"), calls),
            Usage(getInt(usage, "prompt_tokens"), getInt(usage, "completion_tokens")),
            getString(choice, "finish_reason")
        );
        return response;
    }
}
