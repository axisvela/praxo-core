#include "anthropic.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static char response_text[8192];
static char captured_url[512];
static char captured_body[16384];
static char captured_key[128];
static char delta_text[256];
static size_t delta_length = 0;

static const char *fake_transport(const char *url, const char *body,
        const char *api_key, void *ctx, const char **error) {
    (void)ctx;
    snprintf(captured_url, sizeof(captured_url), "%s", url);
    snprintf(captured_body, sizeof(captured_body), "%s", body);
    snprintf(captured_key, sizeof(captured_key), "%s",
        api_key == NULL ? "" : api_key);
    *error = NULL;
    return response_text;
}

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

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxValue *messages = px_parse(&arena,
        "[{\"role\":\"system\",\"content\":\"be brief\"},"
        "{\"role\":\"user\",\"content\":\"hi\"}]");
    PxValue *tools = px_parse(&arena,
        "[{\"name\":\"echo\",\"description\":\"Echo\","
        "\"parameters\":{\"type\":\"object\"}}]");
    snprintf(response_text, sizeof(response_text),
        "{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},"
        "{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\","
        "\"input\":{\"text\":\"hi\"}}],"
        "\"stop_reason\":\"end_turn\","
        "\"usage\":{\"input_tokens\":3,\"output_tokens\":4,"
        "\"cache_read_input_tokens\":2}}");
    PxAnthropic adapter = {
        "https://example.test/", "claude-test", "ak", "2023-06-01", 1024,
        fake_transport, NULL,
    };
    PxValue *response = px_anthropic_generate(&arena, messages, tools, &adapter);
    assert(response != NULL);
    assert(strcmp(captured_url, "https://example.test/v1/messages") == 0);
    assert(strcmp(captured_key, "ak") == 0);
    assert(strcmp(px_get_str(response, "content"), "hello") == 0);
    assert(px_get_num(response, "inputTokens", -1) == 3);
    assert(px_get_num(response, "outputTokens", -1) == 4);
    assert(px_get_num(response, "cachedTokens", -1) == 2);
    assert(strcmp(px_get_str(response, "finishReason"), "end_turn") == 0);
    PxValue *calls = px_obj_get(response, "toolCalls");
    assert(calls != NULL && calls->type == PX_ARR && calls->as.array.len == 1);
    PxValue *call = calls->as.array.items[0];
    assert(strcmp(px_get_str(call, "id"), "tool-1") == 0);
    assert(strcmp(px_get_str(call, "name"), "echo") == 0);
    assert(strcmp(px_get_str(px_obj_get(call, "arguments"), "text"), "hi") == 0);

    PxValue *body = px_parse(&arena, captured_body);
    assert(body != NULL && body->type == PX_OBJ);
    assert(strcmp(px_get_str(body, "model"), "claude-test") == 0);
    assert(strcmp(px_get_str(body, "system"), "be brief") == 0);
    PxValue *wire_tools = px_obj_get(body, "tools");
    assert(wire_tools != NULL && wire_tools->type == PX_ARR
        && wire_tools->as.array.len == 1);
    PxValue *schema = px_obj_get(wire_tools->as.array.items[0], "input_schema");
    assert(schema != NULL && schema->type == PX_OBJ);
    assert(strcmp(px_get_str(schema, "type"), "object") == 0);

    snprintf(response_text, sizeof(response_text),
        "data: {\"type\":\"message_start\",\"message\":{\"usage\":"
        "{\"input_tokens\":4,\"cache_read_input_tokens\":1}}}\n\n"
        "data: {\"type\":\"content_block_start\",\"index\":0,"
        "\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n"
        "data: {\"type\":\"content_block_delta\",\"index\":0,"
        "\"delta\":{\"type\":\"text_delta\",\"text\":\"he\"}}\n\n"
        "data: {\"type\":\"content_block_delta\",\"index\":0,"
        "\"delta\":{\"type\":\"text_delta\",\"text\":\"llo\"}}\n\n"
        "data: {\"type\":\"content_block_start\",\"index\":1,"
        "\"content_block\":{\"type\":\"tool_use\",\"id\":\"call-1\","
        "\"name\":\"echo\",\"input\":{}}}\n\n"
        "data: {\"type\":\"content_block_delta\",\"index\":1,"
        "\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":"
        "\"{\\\"text\\\":\"}}\n\n"
        "data: {\"type\":\"content_block_delta\",\"index\":1,"
        "\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":"
        "\"\\\"hi\\\"}\"}}\n\n"
        "data: {\"type\":\"message_delta\",\"delta\":"
        "{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":2}}\n\n"
        "data: {\"type\":\"message_stop\"}\n\n");
    delta_length = 0;
    delta_text[0] = '\0';
    const char *stream_error = NULL;
    PxValue *streamed = px_anthropic_generate_stream(&arena, messages, tools,
        fake_delta, &adapter, &stream_error);
    assert(streamed != NULL);
    assert(stream_error == NULL);
    assert(strcmp(px_get_str(streamed, "content"), "hello") == 0);
    assert(strcmp(delta_text, "hello") == 0);
    assert(px_get_num(streamed, "inputTokens", -1) == 4);
    assert(px_get_num(streamed, "outputTokens", -1) == 2);
    assert(px_get_num(streamed, "cachedTokens", -1) == 1);
    assert(strcmp(px_get_str(streamed, "finishReason"), "tool_use") == 0);
    PxValue *stream_calls = px_obj_get(streamed, "toolCalls");
    assert(stream_calls != NULL && stream_calls->type == PX_ARR
        && stream_calls->as.array.len == 1);
    PxValue *stream_call = stream_calls->as.array.items[0];
    assert(strcmp(px_get_str(stream_call, "id"), "call-1") == 0);
    assert(strcmp(px_get_str(stream_call, "name"), "echo") == 0);
    assert(strcmp(px_get_str(px_obj_get(stream_call, "arguments"), "text"),
        "hi") == 0);
    PxValue *stream_body = px_parse(&arena, captured_body);
    PxValue *stream_flag = px_obj_get(stream_body, "stream");
    assert(stream_flag != NULL && stream_flag->type == PX_BOOL
        && stream_flag->as.boolean);

    const char *parse_error = NULL;
    assert(px_anthropic_parse_response(&arena, "{\"error\":{}}", &parse_error) == NULL);
    assert(parse_error != NULL && strcmp(parse_error, "PROVIDER_HTTP") == 0);

    px_arena_free(&arena);
    printf("C Anthropic adapter tests passed\n");
    return 0;
}
