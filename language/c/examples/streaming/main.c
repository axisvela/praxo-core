#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    char text[64];
} Buffer;

static PxValue *normal_model(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)messages;
    (void)tools;
    (void)ctx;
    return px_parse(arena, "{\"content\":\"status: green\"}");
}

static const char *capture(const char *delta, void *ctx) {
    Buffer *buffer = ctx;
    strncat(buffer->text, delta, sizeof(buffer->text) - strlen(buffer->text) - 1);
    return NULL;
}

static PxValue *stream_model(PxArena *arena, PxValue *messages,
        PxValue *tools, const char *(*on_delta)(const char *, void *),
        void *ctx, const char **error) {
    (void)messages;
    (void)tools;
    const char *failed = on_delta("status: ", ctx);
    if (failed == NULL) failed = on_delta("green", ctx);
    if (failed != NULL) {
        *error = failed;
        return NULL;
    }
    return normal_model(arena, NULL, NULL, ctx);
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    Buffer buffer = {{0}};
    PxAgentOptions options = {
        .generate = normal_model,
        .generate_stream = stream_model,
        .on_delta = capture,
        .ctx = &buffer,
    };
    PxAgentResult result;
    assert(px_agent_run(&arena, &options, NULL, "Check the status.", &result) == NULL);
    assert(strcmp(buffer.text, "status: green") == 0);
    assert(strcmp(result.output, "status: green") == 0);
    px_arena_free(&arena);
    printf("C streaming example passed\n");
    return 0;
}
