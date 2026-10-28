#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxValue *left = px_parse(&arena, "{\"value\":1}");
    PxValue *right = px_parse(&arena, "{\"value\":1}");
    if (left == NULL || right == NULL || !px_equals(left, right)) {
        return 1;
    }

    PxContextMessage messages[] = {{"user", "hello"}};
    if (px_estimate_tokens(messages, 1) != 5) {
        return 2;
    }

    PxMemoryStore store;
    px_memory_init(&store);
    if (!px_memory_put(&arena, &store, "installed", "m1", "event",
            "hello", "2026-01-01", NULL)) {
        return 3;
    }

    PxMemoryRecord *records = NULL;
    if (px_memory_search(&arena, &store, "installed", "hello", 1, &records) != 1
            || strcmp(records[0].id, "m1") != 0) {
        return 4;
    }

    px_arena_free(&arena);
    puts("installed C consumer passed");
    return 0;
}
