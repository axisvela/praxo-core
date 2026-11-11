#ifndef PRAXO_ANTHROPIC_H
#define PRAXO_ANTHROPIC_H

#include "praxo.h"

typedef const char *(*PxAnthropicTransport)(const char *url, const char *body,
    const char *api_key, void *ctx, const char **error);

typedef struct {
    const char *base_url;
    const char *model;
    const char *api_key;
    const char *version;
    double max_tokens;
    PxAnthropicTransport transport;
    void *transport_ctx;
} PxAnthropic;

PxValue *px_anthropic_request(PxArena *arena, const PxAnthropic *adapter,
    PxValue *messages, PxValue *tools, const char **error);
PxValue *px_anthropic_parse_response(PxArena *arena, const char *text,
    const char **error);
PxValue *px_anthropic_generate(PxArena *arena, PxValue *messages,
    PxValue *tools, void *ctx);
const char *px_anthropic_url(PxArena *arena, const PxAnthropic *adapter);

#endif
