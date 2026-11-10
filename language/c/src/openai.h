#ifndef PRAXO_OPENAI_H
#define PRAXO_OPENAI_H

#include "praxo.h"

typedef const char *(*PxOpenAITransport)(const char *url, const char *body,
    const char *api_key, void *ctx, const char **error);

typedef struct {
    const char *base_url;
    const char *model;
    const char *api_key;
    PxOpenAITransport transport;
    void *transport_ctx;
} PxOpenAICompatible;

PxValue *px_openai_request(PxArena *arena, const PxOpenAICompatible *adapter,
    PxValue *messages, PxValue *tools, const char **error);
PxValue *px_openai_parse_response(PxArena *arena, const char *text,
    const char **error);
PxValue *px_openai_generate(PxArena *arena, PxValue *messages, PxValue *tools,
    void *ctx);
const char *px_openai_url(PxArena *arena, const PxOpenAICompatible *adapter);

#endif
