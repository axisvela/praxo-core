module praxo.openai_compatible;

import std.json : JSONType, JSONValue;
import std.string : stripRight;

import praxo.agent : Model;
import praxo.errors : PraxoError;
import praxo.json : get, getString, getInt, getArray, parse, stringify;
import praxo.models;
import praxo.provider;

class OpenAICompatibleModel : Model {
    string baseUrl;
    string model;
    string apiKey;
    ProviderTransport transport;

    this(string baseUrl, string model, string apiKey = null,
         ProviderTransport transport = null) {
        this.baseUrl = baseUrl.stripRight("/");
        this.model = model;
        this.apiKey = apiKey;
        this.transport = transport;
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
