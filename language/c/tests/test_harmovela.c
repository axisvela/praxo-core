#include "harmovela.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    int status;
    const char *body;
} Fake;

static char captured_method[16];
static char captured_url[512];
static char captured_type[64];
static char captured_body[16384];
static int transport_calls = 0;

static bool fake_transport(const char *method, const char *url,
        const char *content_type, const char *body, void *ctx,
        PxHarmovelaResponse *response, const char **error) {
    Fake *fake = (Fake *)ctx;
    transport_calls++;
    snprintf(captured_method, sizeof(captured_method), "%s", method);
    snprintf(captured_url, sizeof(captured_url), "%s", url);
    snprintf(captured_type, sizeof(captured_type), "%s", content_type);
    snprintf(captured_body, sizeof(captured_body), "%s", body);
    response->status = fake->status;
    response->body = fake->body;
    if (error != NULL) {
        *error = NULL;
    }
    return true;
}

static long long fixed_clock(void *ctx) {
    (void)ctx;
    return 1794294000000000000LL;
}

static PxEvent make_event(PxArena *arena, PxValue *data, const char *run_id) {
    PxEvent event;
    event.kind = "tool.call";
    event.session_id = "s1";
    event.run_id = run_id;
    event.data = data;
    (void)arena;
    return event;
}

static const char *text_field(const PxValue *object, const char *key) {
    const char *value = px_get_str(object, key);
    assert(value != NULL);
    return value;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    Fake fake;
    fake.status = 201;
    fake.body = "";
    PxHarmovelaSink sink = px_harmovela_sink(
        "http://harmovela.test/aep/api/", "praxo-core", "0.2",
        fake_transport, &fake);
    sink.clock = fixed_clock;
    PxEvent event = make_event(&arena, px_parse(&arena, "{\"name\":\"echo\"}"),
        "run-123");
    const char *error = NULL;
    assert(px_harmovela_emit(&arena, &sink, &event, &error));
    assert(error == NULL);
    assert(transport_calls == 1);
    assert(strcmp(captured_method, "POST") == 0);
    assert(strcmp(captured_url, "http://harmovela.test/aep/api/events") == 0);
    assert(strcmp(captured_type, "application/json") == 0);
    PxValue *envelope = px_parse(&arena, captured_body);
    assert(envelope != NULL);
    assert(strcmp(text_field(envelope, "spec_version"), "0.2") == 0);
    assert(strcmp(text_field(envelope, "id"),
        "run-123-1794294000000000000") == 0);
    assert(strcmp(text_field(envelope, "type"), "tool.call") == 0);
    assert(strcmp(text_field(envelope, "source"), "praxo-core") == 0);
    assert(strcmp(text_field(envelope, "created_at"),
        "2026-11-10T07:00:00.000000000Z") == 0);
    PxValue *payload = px_obj_get(envelope, "payload");
    assert(payload != NULL && payload->type == PX_OBJ);
    assert(strcmp(text_field(payload, "name"), "echo") == 0);
    assert(strcmp(text_field(payload, "session_id"), "s1") == 0);
    assert(strcmp(text_field(payload, "run_id"), "run-123") == 0);

    transport_calls = 0;
    PxHarmovelaSink custom = px_harmovela_sink(
        "http://harmovela.test", "custom", "0.3", fake_transport, &fake);
    custom.clock = fixed_clock;
    PxValue *merged_data = px_parse(&arena,
        "{\"name\":\"echo\",\"session_id\":\"event-side\",\"run_id\":\"old\"}");
    PxEvent merged = make_event(&arena, merged_data, NULL);
    assert(px_harmovela_emit(&arena, &custom, &merged, &error));
    PxValue *merged_envelope = px_parse(&arena, captured_body);
    assert(strcmp(text_field(merged_envelope, "source"), "custom") == 0);
    assert(strcmp(text_field(merged_envelope, "spec_version"), "0.3") == 0);
    assert(strncmp(text_field(merged_envelope, "id"), "s1-", 3) == 0);
    PxValue *merged_payload = px_obj_get(merged_envelope, "payload");
    assert(strcmp(text_field(merged_payload, "session_id"), "s1") == 0);
    assert(strcmp(text_field(merged_payload, "run_id"), "old") == 0);

    const int accepted[] = {200, 201, 204, 299};
    for (size_t index = 0; index < sizeof(accepted) / sizeof(accepted[0]);
            index++) {
        fake.status = accepted[index];
        assert(px_harmovela_emit(&arena, &sink, &event, &error));
    }

    char repeated[1400];
    repeated[0] = '\0';
    for (int index = 0; index < 100; index++) {
        strcat(repeated, "service down ");
    }
    fake.status = 503;
    fake.body = repeated;
    assert(!px_harmovela_emit(&arena, &sink, &event, &error));
    assert(error != NULL);
    assert(strstr(error, "503") != NULL);
    assert(strstr(error, "service down") != NULL);
    assert(strlen(error) <= 600);

    px_arena_free(&arena);
    printf("C harmovela tests passed\n");
    return 0;
}
