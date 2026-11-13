#include "retriever.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static PxDocument *fake_retrieve(PxArena *arena, const char *query, int limit,
        size_t *count, void *ctx, const char **error) {
    (void)ctx;
    if (error != NULL) {
        *error = NULL;
    }
    PxDocument *documents = px_arena_alloc(arena, sizeof(PxDocument));
    char content[128];
    snprintf(content, sizeof(content), "%s:%d", query, limit);
    documents[0] = *px_document(arena, "doc-1", content, NULL, 0.5);
    if (count != NULL) {
        *count = 1;
    }
    return documents;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxRetriever retriever = px_retriever(fake_retrieve, NULL);
    size_t count = 0;
    const char *error = NULL;
    PxDocument *documents = px_retrieve(&arena, retriever, "hello", 3, &count,
        &error);
    assert(error == NULL);
    assert(count == 1);
    assert(strcmp(documents[0].id, "doc-1") == 0);
    assert(strcmp(documents[0].content, "hello:3") == 0);
    assert(documents[0].score == 0.5);
    px_arena_free(&arena);
    return 0;
}
