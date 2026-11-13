#include "otel.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static char captured_body[16384];
static int captured_status = 200;

static bool fake_transport(const char *method, const char *url,
        const char *content_type, const char *body, void *ctx,
        PxOtelResponse *response, const char **error) {
    (void)ctx;
    assert(strcmp(method, "POST") == 0);
    assert(strcmp(url, "http://otel.test/v1/traces") == 0);
    assert(strcmp(content_type, "application/json") == 0);
    snprintf(captured_body, sizeof(captured_body), "%s", body);
    response->status = captured_status;
    response->body = "";
    if (error != NULL) {
        *error = NULL;
    }
    return true;
}

static PxValue *find_span(PxArena *arena, PxValue *payload) {
    PxValue *resource_spans = px_obj_get(payload, "resourceSpans");
    assert(resource_spans != NULL && resource_spans->type == PX_ARR);
    PxValue *resource_span = resource_spans->as.array.items[0];
    PxValue *scope_spans = px_obj_get(resource_span, "scopeSpans");
    PxValue *scope_span = scope_spans->as.array.items[0];
    PxValue *spans = px_obj_get(scope_span, "spans");
    return spans->as.array.items[0];
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    const char *keys[] = {"name"};
    PxOtelSink sink = px_otel_sink("http://otel.test/v1/traces",
        "praxo-test", fake_transport, NULL);
    sink.allowed_data_keys = keys;
    sink.allowed_data_key_count = 1;
    PxEvent event;
    event.kind = "tool.call";
    event.session_id = "s1";
    event.run_id = "run-123";
    event.data = px_parse(&arena,
        "{\"name\":\"echo\",\"secret\":\"hidden\"}");
    const char *error = NULL;
    assert(px_otel_emit(&arena, &sink, &event, &error));
    assert(error == NULL);

    PxValue *payload = px_parse(&arena, captured_body);
    assert(payload != NULL);
    PxValue *span = find_span(&arena, payload);
    assert(strcmp(px_get_str(span, "name"), "praxo.tool.call") == 0);
    assert(strlen(px_get_str(span, "traceId")) == 32);
    assert(strlen(px_get_str(span, "spanId")) == 16);
    PxValue *attributes = px_obj_get(span, "attributes");
    assert(attributes != NULL && attributes->type == PX_ARR);
    int found_name = 0;
    int found_secret = 0;
    for (size_t index = 0; index < attributes->as.array.len; index++) {
        PxValue *item = attributes->as.array.items[index];
        const char *key = px_get_str(item, "key");
        PxValue *value = px_obj_get(item, "value");
        const char *text = px_get_str(value, "stringValue");
        if (strcmp(key, "praxo.event.data.name") == 0 &&
                strcmp(text, "echo") == 0) {
            found_name = 1;
        }
        if (strcmp(key, "praxo.event.data.secret") == 0) {
            found_secret = 1;
        }
    }
    assert(found_name == 1);
    assert(found_secret == 0);

    captured_status = 503;
    assert(!px_otel_emit(&arena, &sink, &event, &error));
    assert(strcmp(error, "OTEL_HTTP") == 0);

    px_arena_free(&arena);
    return 0;
}
