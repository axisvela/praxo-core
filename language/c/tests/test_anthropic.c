#include "anthropic.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static char response_text[8192];
static char captured_url[512];
static char captured_body[16384];
static char captured_key[128];

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

    const char *parse_error = NULL;
    assert(px_anthropic_parse_response(&arena, "{\"error\":{}}", &parse_error) == NULL);
    assert(parse_error != NULL && strcmp(parse_error, "PROVIDER_HTTP") == 0);

    px_arena_free(&arena);
    printf("C Anthropic adapter tests passed\n");
    return 0;
}
