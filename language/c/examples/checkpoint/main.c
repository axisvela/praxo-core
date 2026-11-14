#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxAllowlist allow;
    px_checkpoint_init(&allow);

    assert(px_checkpoint_register(&arena, &allow, "order"));
    PxValue *value = px_parse(&arena, "{\"value\":\"x\"}");
    assert(value != NULL);

    char *encoded = NULL;
    const char *error = px_checkpoint_marshal(&arena, &allow, "order", value, &encoded);
    assert(error == NULL && encoded != NULL);

    PxValue *decoded = NULL;
    error = px_checkpoint_unmarshal(&arena, &allow, encoded, &decoded);
    assert(error == NULL && px_equals(decoded, value));

    char *missing = NULL;
    error = px_checkpoint_marshal(&arena, &allow, "missing", value, &missing);
    assert(error != NULL && strcmp(error, "CHECKPOINT_TYPE_NOT_ALLOWED") == 0);

    px_arena_free(&arena);
    printf("C checkpoint example passed\n");
    return 0;
}
