#include <cassert>
#include <iostream>
#include <map>
#include <string>

#include "praxo/anthropic.hpp"
#include "praxo/gemini.hpp"

using namespace praxo;

static Request provider_request() {
    Request request;
    Message system;
    system.role = SYSTEM;
    system.content = "be brief";
    Message user;
    user.role = USER;
    user.content = "hi";
    request.messages = {system, user};
    ToolSpec tool;
    tool.name = "echo";
    tool.description = "Echo";
    tool.parameters = Json::parse(R"({"type":"object"})");
    request.tools = {tool};
    request.tool_choice = "auto";
    return request;
}

int main() {
    std::string path;
    Json payload = Json(nullptr);
    AnthropicOptions anthropic_options;
    anthropic_options.model = "claude-test";
    anthropic_options.api_key = "ak";
    Anthropic anthropic(anthropic_options,
        [&](const std::string& url, const Json& body,
            const std::map<std::string, std::string>& headers) {
            path = url;
            payload = body;
            assert(headers.at("x-api-key") == "ak");
            return Json::parse(R"({
                "content": [
                    {"type": "text", "text": "hello"},
                    {"type": "tool_use", "id": "tool-1", "name": "echo",
                     "input": {"text": "hi"}}
                ],
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 3, "output_tokens": 4,
                          "cache_read_input_tokens": 2}
            })");
        });
    auto anthropic_response = anthropic.generate(provider_request());
    assert(path == "https://api.anthropic.com/v1/messages");
    assert(payload.at("system").as_string() == "be brief");
    assert(payload.at("tools").as_array().size() == 1);
    assert(anthropic_response.message.content.value() == "hello");
    assert(anthropic_response.message.tool_calls.at(0).id == "tool-1");
    assert(anthropic_response.usage.cached_tokens == 2);
    assert(anthropic_response.finish_reason.value() == "end_turn");

    const std::string anthropic_sse = R"(data: {"type":"message_start","message":{"usage":{"input_tokens":4,"cache_read_input_tokens":1}}}

data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}

data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-1","name":"echo","input":{}}}

data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}

data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}

data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}

data: {"type":"message_stop"}

)";
    Anthropic streaming_anthropic(anthropic_options,
        [](const std::string&, const Json&,
           const std::map<std::string, std::string>&) {
            return Json(nullptr);
        },
        [&](const std::string&, const Json& body,
            const std::map<std::string, std::string>& headers) {
            assert(headers.at("accept") == "text/event-stream");
            assert(body.at("stream") == Json(true));
            return anthropic_sse;
        });
    std::string anthropic_deltas;
    auto streamed = streaming_anthropic.generate_stream(
        provider_request(),
        [&](const std::string& delta) { anthropic_deltas += delta; });
    assert(anthropic_deltas == "hello");
    assert(streamed.message.content.value() == "hello");
    assert(streamed.message.tool_calls.at(0).id == "call-1");
    assert(streamed.message.tool_calls.at(0).name == "echo");
    assert(streamed.message.tool_calls.at(0).arguments ==
           Json::parse(R"({"text":"hi"})"));
    assert(streamed.usage.input_tokens == 4);
    assert(streamed.usage.output_tokens == 2);
    assert(streamed.usage.cached_tokens == 1);
    assert(streamed.finish_reason.value() == "tool_use");

    GeminiOptions gemini_options;
    gemini_options.model = "gemini-test";
    gemini_options.api_key = "gk";
    Gemini gemini(gemini_options,
        [&](const std::string& url, const Json& body,
            const std::map<std::string, std::string>& headers) {
            path = url;
            payload = body;
            assert(headers.at("x-goog-api-key") == "gk");
            return Json::parse(R"({
                "candidates": [{
                    "content": {"parts": [
                        {"text": "hello"},
                        {"functionCall": {"name": "echo", "args": {"text": "hi"}}}
                    ]},
                    "finishReason": "STOP"
                }],
                "usageMetadata": {"promptTokenCount": 3,
                                  "candidatesTokenCount": 4}
            })");
        });
    auto gemini_response = gemini.generate(provider_request());
    assert(path.find(":generateContent") != std::string::npos);
    assert(payload.at("system_instruction").at("parts").as_array().size() == 1);
    assert(gemini_response.message.content.value() == "hello");
    assert(gemini_response.message.tool_calls.at(0).name == "echo");
    assert(gemini_response.usage.input_tokens == 3);
    assert(gemini_response.finish_reason.value() == "STOP");

    Gemini streaming_gemini(gemini_options,
        [](const std::string&, const Json&,
           const std::map<std::string, std::string>&) { return Json(nullptr); },
        [&](const std::string& url, const Json&,
            const std::map<std::string, std::string>& headers) {
            assert(url.find(":streamGenerateContent?alt=sse") != std::string::npos);
            assert(headers.at("accept") == "text/event-stream");
            return std::string(
                "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"he\"}]}}]}\n\n"
                "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"llo\"},"
                "{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},"
                "\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":4,"
                "\"candidatesTokenCount\":2,\"cachedContentTokenCount\":1}}");
        });
    std::string gemini_deltas;
    auto gemini_streamed = streaming_gemini.generate_stream(
        provider_request(),
        [&](const std::string& delta) { gemini_deltas += delta; });
    assert(gemini_deltas == "hello");
    assert(gemini_streamed.message.content.value() == "hello");
    assert(gemini_streamed.message.tool_calls.at(0).name == "echo");
    assert(gemini_streamed.message.tool_calls.at(0).arguments ==
           Json::parse(R"({"text":"hi"})"));
    assert(gemini_streamed.usage.input_tokens == 4);
    assert(gemini_streamed.usage.output_tokens == 2);
    assert(gemini_streamed.usage.cached_tokens == 1);
    assert(gemini_streamed.finish_reason.value() == "STOP");

    bool rejected = false;
    try {
        AnthropicOptions invalid;
        invalid.model = "m";
        Anthropic broken(invalid,
            [](const std::string&, const Json&,
               const std::map<std::string, std::string>&) { return Json(nullptr); });
        broken.generate(provider_request());
    } catch (const PraxoError&) {
        rejected = true;
    }
    assert(rejected);

    std::cout << "cpp provider adapter tests passed\n";
    return 0;
}
