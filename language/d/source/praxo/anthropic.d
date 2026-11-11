module praxo.anthropic;

import std.json : JSONType, JSONValue;
import std.string : stripRight;

import praxo.agent : Model;
import praxo.errors : PraxoError;
import praxo.json : get, getString, getInt, getArray, stringify;
import praxo.models;
import praxo.provider;

class AnthropicModel : Model {
    string baseUrl;
    string model;
    string apiKey;
    string apiVersion;
    int maxTokens;
    ProviderTransport transport;

    this(string model, string apiKey, string baseUrl = "https://api.anthropic.com",
         string apiVersion = "2023-06-01", int maxTokens = 1024,
         ProviderTransport transport = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.model = model;
        this.apiKey = apiKey;
        this.apiVersion = apiVersion;
        this.maxTokens = maxTokens;
        this.transport = transport;
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

    JSONValue buildPayload(Request request) {
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
