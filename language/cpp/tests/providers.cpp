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
