#ifndef PRAXO_GEMINI_H
#define PRAXO_GEMINI_H

#include "praxo.h"

typedef const char *(*PxGeminiTransport)(const char *url, const char *body,
    const char *api_key, void *ctx, const char **error);

typedef struct {
    const char *base_url;
    const char *model;
    const char *api_key;
    double max_output_tokens;
    PxGeminiTransport transport;
    void *transport_ctx;
} PxGemini;

PxValue *px_gemini_request(PxArena *arena, const PxGemini *adapter,
    PxValue *messages, PxValue *tools, const char **error);
PxValue *px_gemini_parse_response(PxArena *arena, const char *text,
    const char **error);
PxValue *px_gemini_generate(PxArena *arena, PxValue *messages, PxValue *tools,
    void *ctx);
const char *px_gemini_url(PxArena *arena, const PxGemini *adapter);

#endif
