#ifndef PRAXO_RETRIEVER_H
#define PRAXO_RETRIEVER_H

#include <stdbool.h>
#include <stddef.h>

#include "praxo.h"

typedef struct {
    const char *id;
    const char *content;
    PxValue *metadata;
    double score;
} PxDocument;

typedef PxDocument *(*PxRetrieverFunction)(PxArena *arena, const char *query,
    int limit, size_t *count, void *ctx, const char **error);

typedef struct {
    PxRetrieverFunction retrieve;
    void *ctx;
} PxRetriever;

PxRetriever px_retriever(PxRetrieverFunction retrieve, void *ctx);

PxDocument *px_document(PxArena *arena, const char *id, const char *content,
    PxValue *metadata, double score);

PxDocument *px_retrieve(PxArena *arena, PxRetriever retriever,
    const char *query, int limit, size_t *count, const char **error);

#endif
