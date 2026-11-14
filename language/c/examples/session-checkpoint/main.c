#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

static PxValue *turn_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)tools;
    (void)ctx;
    char content[32];
    snprintf(content, sizeof(content), "turn %zu", messages->as.array.len);
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, content));
    return response;
}

static void append_message(PxArena *arena, PxValue *messages, const char *role,
        const char *content) {
    PxValue *message = px_obj(arena);
    px_obj_set(arena, message, "role", px_str(arena, role));
    px_obj_set(arena, message, "content", px_str(arena, content));
    px_arr_push(arena, messages, message);
}

static PxValue *history(PxArena *arena) {
    PxValue *messages = px_arr(arena);
    append_message(arena, messages, "user", "first");
    append_message(arena, messages, "assistant", "ack");
    return messages;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxAgentOptions options = {
        .generate = turn_model,
        .max_steps = 2,
    };

    PxValue *messages = history(&arena);
    PxAgentResult result;
    const char *error = px_agent_run(&arena, &options, messages, "second",
        &result);
    if (error != NULL || strcmp(result.output, "turn 3") != 0) {
        fprintf(stderr, "second turn failed: %s\n", error == NULL ? "" : error);
        return 1;
    }

    append_message(&arena, messages, "user", "second");
    append_message(&arena, messages, "assistant", result.output);

    PxAllowlist allow;
    px_checkpoint_init(&allow);
    if (!px_checkpoint_register(&arena, &allow, "session")) {
        fprintf(stderr, "checkpoint register failed\n");
        return 1;
    }
    PxValue *payload = px_obj(&arena);
    px_obj_set(&arena, payload, "messages", messages);
    char *encoded = NULL;
    error = px_checkpoint_marshal(&arena, &allow, "session", payload, &encoded);
    if (error != NULL) {
        fprintf(stderr, "checkpoint marshal failed: %s\n", error);
        return 1;
    }
    PxValue *decoded = NULL;
    error = px_checkpoint_unmarshal(&arena, &allow, encoded, &decoded);
    if (error != NULL) {
        fprintf(stderr, "checkpoint unmarshal failed: %s\n", error);
        return 1;
    }
    PxValue *restored = px_obj_get(decoded, "messages");
    if (restored == NULL) {
        fprintf(stderr, "checkpoint missing messages\n");
        return 1;
    }

    error = px_agent_run(&arena, &options, restored, "third", &result);
    if (error != NULL || strcmp(result.output, "turn 5") != 0) {
        fprintf(stderr, "third turn failed: %s\n", error == NULL ? "" : error);
        return 1;
    }

    printf("restored messages: %zu\n", restored->as.array.len);
    printf("output: %s\n", result.output);

    px_arena_free(&arena);
    return 0;
}
