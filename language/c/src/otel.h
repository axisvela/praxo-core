#ifndef PRAXO_OTEL_H
#define PRAXO_OTEL_H

#include <stdbool.h>
#include <stddef.h>

#include "praxo.h"
#include "praxo_core.h"

typedef struct {
    int status;
    const char *body;
} PxOtelResponse;

typedef bool (*PxOtelTransport)(const char *method, const char *url,
    const char *content_type, const char *body, void *ctx,
    PxOtelResponse *response, const char **error);

typedef struct {
    const char *endpoint;
    const char *service_name;
    const char **allowed_data_keys;
    size_t allowed_data_key_count;
    PxOtelTransport transport;
    void *ctx;
} PxOtelSink;

PxOtelSink px_otel_sink(const char *endpoint, const char *service_name,
    PxOtelTransport transport, void *ctx);

char *px_otel_payload(PxArena *arena, const PxOtelSink *sink,
    const PxEvent *event);

bool px_otel_emit(PxArena *arena, const PxOtelSink *sink,
    const PxEvent *event, const char **error);

#endif
