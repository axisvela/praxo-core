#include "retriever.h"

PxRetriever px_retriever(PxRetrieverFunction retrieve, void *ctx) {
    PxRetriever retriever;
    retriever.retrieve = retrieve;
    retriever.ctx = ctx;
    return retriever;
}

PxDocument *px_document(PxArena *arena, const char *id, const char *content,
        PxValue *metadata, double score) {
    PxDocument *document = px_arena_alloc(arena, sizeof(PxDocument));
    if (document == NULL) {
        return NULL;
    }
    document->id = px_arena_strdup(arena, id == NULL ? "" : id);
    document->content = px_arena_strdup(arena, content == NULL ? "" : content);
    document->metadata = metadata == NULL ? px_obj(arena) : metadata;
    document->score = score;
    return document;
}

PxDocument *px_retrieve(PxArena *arena, PxRetriever retriever,
        const char *query, int limit, size_t *count, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (count != NULL) {
        *count = 0;
    }
    if (retriever.retrieve == NULL) {
        if (error != NULL) {
            *error = "RETRIEVER_INVALID";
        }
        return NULL;
    }
    if (query == NULL || limit < 0) {
        if (error != NULL) {
            *error = "RETRIEVER_INVALID";
        }
        return NULL;
    }
    return retriever.retrieve(arena, query, limit, count, retriever.ctx, error);
}
