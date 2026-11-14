#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxStructuredOutput config = {
        .schema = px_parse(&arena,
            "{\"type\":\"object\",\"required\":[\"name\"],"
            "\"properties\":{\"name\":{\"type\":\"string\"}}}"),
        .max_repairs = 0,
    };

    char *output = px_apply_structured(&arena, &config, "{\"name\":\"ok\"}");
    assert(output != NULL);

    output = px_apply_structured(&arena, &config, "{}");
    assert(output == NULL);

    px_arena_free(&arena);
    printf("C structured output example passed\n");
    return 0;
}
