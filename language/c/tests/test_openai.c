#include "openai.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static char response_text[8192];
static char captured_url[512];
static char captured_body[16384];
static char captured_key[128];
static char delta_text[256];
static size_t delta_length = 0;
static int transport_calls = 0;

static const char *fake_delta(const char *delta, void *ctx) {
    (void)ctx;
    size_t length = strlen(delta);
    if (delta_length + length + 1 < sizeof(delta_text)) {
        memcpy(delta_text + delta_length, delta, length);
        delta_length += length;
        delta_text[delta_length] = '\0';
    }
    return NULL;
}

static const char *fake_transport(const char *url, const char *body,
        const char *api_key, void *ctx, const char **error) {
    (void)ctx;
    transport_calls++;
    snprintf(captured_url, sizeof(captured_url), "%s", url);
    snprintf(captured_body, sizeof(captured_body), "%s", body);
    snprintf(captured_key, sizeof(captured_key), "%s",
        api_key == NULL ? "" : api_key);
    *error = NULL;
    return response_text;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxValue *messages = px_parse(&arena,
        "[{\"role\":\"user\",\"content\":\"hello\"},"
        "{\"role\":\"assistant\",\"content\":\"\",\"toolCalls\":["
        "{\"id\":\"prior\",\"name\":\"echo\",\"arguments\":{\"a\":1}}]},"
        "{\"role\":\"tool\",\"content\":\"{\\\"ok\\\":true}\",\"toolId\":\"prior\"}]");
    PxValue *tools = px_parse(&arena,
        "[{\"name\":\"echo\",\"description\":\"Echo arguments\","
        "\"parameters\":{\"type\":\"object\"}}]");
    const char *error = NULL;
    PxOpenAICompatible adapter;
    adapter.base_url = "https://example.test/v1/";
    adapter.model = "test-model";
    adapter.api_key = "secret";
    adapter.transport = fake_transport;
    adapter.transport_ctx = NULL;
    snprintf(response_text, sizeof(response_text),
        "{\"choices\":[{\"message\":{\"content\":\"hello\",\"tool_calls\":["
        "{\"id\":\"call-1\",\"type\":\"function\",\"function\":{\"name\":\"echo\","
        "\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]},"
        "\"finish_reason\":\"tool_calls\"}],"
        "\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2}}");

    PxValue *response = px_openai_generate(&arena, messages, tools, &adapter);
    assert(response != NULL);
    assert(transport_calls == 1);
    assert(strcmp(captured_url, "https://example.test/v1/chat/completions") == 0);
    assert(strcmp(captured_key, "secret") == 0);
    assert(strcmp(px_get_str(response, "content"), "hello") == 0);
    assert(px_get_num(response, "inputTokens", -1) == 3);
    assert(px_get_num(response, "outputTokens", -1) == 2);
    assert(strcmp(px_get_str(response, "finishReason"), "tool_calls") == 0);
    PxValue *calls = px_obj_get(response, "toolCalls");
    assert(calls != NULL && calls->type == PX_ARR && calls->as.array.len == 1);
    PxValue *call = calls->as.array.items[0];
    assert(strcmp(px_get_str(call, "id"), "call-1") == 0);
    assert(strcmp(px_get_str(call, "name"), "echo") == 0);
    PxValue *arguments = px_obj_get(call, "arguments");
    assert(arguments != NULL && arguments->type == PX_OBJ);
    assert(strcmp(px_get_str(arguments, "text"), "hi") == 0);

    PxValue *body = px_parse(&arena, captured_body);
    assert(body != NULL && body->type == PX_OBJ);
    assert(strcmp(px_get_str(body, "model"), "test-model") == 0);
    PxValue *wire_messages = px_obj_get(body, "messages");
    assert(wire_messages != NULL && wire_messages->type == PX_ARR
        && wire_messages->as.array.len == 3);
    PxValue *first = wire_messages->as.array.items[0];
    assert(strcmp(px_get_str(first, "role"), "user") == 0);
    assert(strcmp(px_get_str(first, "content"), "hello") == 0);
    PxValue *second = wire_messages->as.array.items[1];
    PxValue *wire_calls = px_obj_get(second, "tool_calls");
    assert(wire_calls != NULL && wire_calls->type == PX_ARR
        && wire_calls->as.array.len == 1);
    PxValue *wire_call = wire_calls->as.array.items[0];
    assert(strcmp(px_get_str(wire_call, "id"), "prior") == 0);
    assert(strcmp(px_get_str(wire_call, "type"), "function") == 0);
    PxValue *function = px_obj_get(wire_call, "function");
    assert(strcmp(px_get_str(function, "name"), "echo") == 0);
    assert(strcmp(px_get_str(function, "arguments"), "{\"a\":1}") == 0);
    PxValue *third = wire_messages->as.array.items[2];
    assert(strcmp(px_get_str(third, "tool_call_id"), "prior") == 0);
    PxValue *wire_tools = px_obj_get(body, "tools");
    assert(wire_tools != NULL && wire_tools->type == PX_ARR
        && wire_tools->as.array.len == 1);
    PxValue *wire_tool = wire_tools->as.array.items[0];
    assert(strcmp(px_get_str(wire_tool, "type"), "function") == 0);
    PxValue *tool_function = px_obj_get(wire_tool, "function");
    assert(strcmp(px_get_str(tool_function, "name"), "echo") == 0);
    PxValue *parameters = px_obj_get(tool_function, "parameters");
    assert(parameters != NULL && parameters->type == PX_OBJ);
    assert(strcmp(px_get_str(parameters, "type"), "object") == 0);

    PxValue *block_messages = px_parse(&arena,
        "[{\"role\":\"user\",\"content\":\"\",\"contentBlocks\":["
        "{\"type\":\"text\",\"text\":\"a\"},{\"type\":\"text\",\"text\":\"b\"}]}]");
    PxValue *block_request = px_openai_request(&arena, &adapter, block_messages,
        NULL, &error);
    assert(block_request != NULL && error == NULL);
    PxValue *block_wire = px_obj_get(block_request, "messages");
    assert(strcmp(px_get_str(block_wire->as.array.items[0], "content"), "ab") == 0);

    snprintf(response_text, sizeof(response_text),
        "data: {\"choices\":[{\"delta\":{\"content\":\"he\"}}]}\n\n"
        "data: {\"choices\":[{\"delta\":{\"content\":\"llo\"}}]}\n\n"
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,"
        "\"id\":\"call-1\",\"function\":{\"name\":\"ec\","
        "\"arguments\":\"{\\\"text\\\":\"}}]}}]}\n\n"
        "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,"
        "\"function\":{\"name\":\"ho\",\"arguments\":\"\\\"hi\\\"}\"}}]}}],"
        "\"usage\":{\"prompt_tokens\":4,\"completion_tokens\":2}}\n\n"
        "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\n"
        "data: [DONE]\n\n");
    delta_length = 0;
    delta_text[0] = '\0';
    const char *stream_error = NULL;
    PxValue *streamed = px_openai_generate_stream(&arena, messages, tools,
        fake_delta, &adapter, &stream_error);
    assert(streamed != NULL);
    assert(stream_error == NULL);
    assert(strcmp(px_get_str(streamed, "content"), "hello") == 0);
    assert(strcmp(delta_text, "hello") == 0);
    assert(px_get_num(streamed, "inputTokens", -1) == 4);
    assert(px_get_num(streamed, "outputTokens", -1) == 2);
    assert(strcmp(px_get_str(streamed, "finishReason"), "tool_calls") == 0);
    PxValue *stream_calls = px_obj_get(streamed, "toolCalls");
    assert(stream_calls != NULL && stream_calls->type == PX_ARR
        && stream_calls->as.array.len == 1);
    PxValue *stream_call = stream_calls->as.array.items[0];
    assert(strcmp(px_get_str(stream_call, "id"), "call-1") == 0);
    assert(strcmp(px_get_str(stream_call, "name"), "echo") == 0);
    PxValue *stream_arguments = px_obj_get(stream_call, "arguments");
    assert(stream_arguments != NULL && stream_arguments->type == PX_OBJ);
    assert(strcmp(px_get_str(stream_arguments, "text"), "hi") == 0);
    PxValue *stream_body = px_parse(&arena, captured_body);
    PxValue *stream_flag = px_obj_get(stream_body, "stream");
    assert(stream_flag != NULL && stream_flag->type == PX_BOOL
        && stream_flag->as.boolean);

    snprintf(response_text, sizeof(response_text),
        "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n");
    delta_length = 0;
    delta_text[0] = '\0';
    stream_error = NULL;
    assert(px_openai_generate_stream(&arena, messages, tools, fake_delta,
        &adapter, &stream_error) == NULL);
    assert(stream_error != NULL && strcmp(stream_error, "MODEL_STREAM") == 0);

    int calls_before_invalid = transport_calls;
    PxOpenAICompatible invalid = adapter;
    invalid.base_url = "";
    assert(px_openai_generate(&arena, messages, tools, &invalid) == NULL);
    assert(transport_calls == calls_before_invalid);

    PxOpenAICompatible direct = adapter;
    direct.base_url = "https://example.test/v1/chat/completions";
    assert(strcmp(px_openai_url(&arena, &direct),
        "https://example.test/v1/chat/completions") == 0);

    snprintf(response_text, sizeof(response_text),
        "{\"choices\":[{\"message\":{\"content\":\"\",\"tool_calls\":["
        "{\"id\":\"x\",\"function\":{\"name\":\"echo\",\"arguments\":\"broken\"}}]}}]}");
    const char *parse_error = NULL;
    assert(px_openai_parse_response(&arena, response_text, &parse_error) == NULL);
    assert(parse_error != NULL && strcmp(parse_error, "PROVIDER_JSON") == 0);

    px_arena_free(&arena);
    printf("C OpenAI-compatible adapter tests passed\n");
    return 0;
}
