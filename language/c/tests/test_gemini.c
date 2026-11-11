#include "gemini.h"

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
        "{\"candidates\":[{\"content\":{\"parts\":["
        "{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\","
        "\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],"
        "\"usageMetadata\":{\"promptTokenCount\":3,"
        "\"candidatesTokenCount\":4,\"cachedContentTokenCount\":2}}");
    PxGemini adapter = {
        "https://example.test/", "gemini-test", "gk", 0, fake_transport, NULL,
    };
    PxValue *response = px_gemini_generate(&arena, messages, tools, &adapter);
    assert(response != NULL);
    assert(strcmp(captured_url,
        "https://example.test/v1beta/models/gemini-test:generateContent") == 0);
    assert(strcmp(captured_key, "gk") == 0);
    assert(strcmp(px_get_str(response, "content"), "hello") == 0);
    assert(px_get_num(response, "inputTokens", -1) == 3);
    assert(px_get_num(response, "outputTokens", -1) == 4);
    assert(px_get_num(response, "cachedTokens", -1) == 2);
    assert(strcmp(px_get_str(response, "finishReason"), "STOP") == 0);
    PxValue *calls = px_obj_get(response, "toolCalls");
    assert(calls != NULL && calls->type == PX_ARR && calls->as.array.len == 1);
    PxValue *call = calls->as.array.items[0];
    assert(strcmp(px_get_str(call, "name"), "echo") == 0);
    assert(strcmp(px_get_str(px_obj_get(call, "arguments"), "text"), "hi") == 0);

    PxValue *body = px_parse(&arena, captured_body);
    assert(body != NULL && body->type == PX_OBJ);
    PxValue *contents = px_obj_get(body, "contents");
    assert(contents != NULL && contents->type == PX_ARR && contents->as.array.len > 0);
    PxValue *system = px_obj_get(body, "system_instruction");
    assert(system != NULL && system->type == PX_OBJ);
    PxValue *config = px_obj_get(body, "toolConfig");
    assert(config != NULL && config->type == PX_OBJ);
    PxValue *calling = px_obj_get(config, "functionCallingConfig");
    assert(strcmp(px_get_str(calling, "mode"), "AUTO") == 0);

    const char *parse_error = NULL;
    assert(px_gemini_parse_response(&arena, "{\"error\":{}}", &parse_error) == NULL);
    assert(parse_error != NULL && strcmp(parse_error, "PROVIDER_HTTP") == 0);

    px_arena_free(&arena);
    printf("C Gemini adapter tests passed\n");
    return 0;
}
