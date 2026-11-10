#ifndef PRAXO_HARMOVELA_H
#define PRAXO_HARMOVELA_H

#include <stdbool.h>

#include "praxo.h"
#include "praxo_core.h"

typedef struct {
    int status;
    const char *body;
} PxHarmovelaResponse;

typedef bool (*PxHarmovelaTransport)(const char *method, const char *url,
    const char *content_type, const char *body, void *ctx,
    PxHarmovelaResponse *response, const char **error);

typedef long long (*PxHarmovelaClock)(void *ctx);

typedef struct {
    const char *base_url;
    const char *source;
    const char *spec_version;
    PxHarmovelaTransport transport;
    void *transport_ctx;
    PxHarmovelaClock clock;
    void *clock_ctx;
} PxHarmovelaSink;

PxHarmovelaSink px_harmovela_sink(const char *base_url, const char *source,
    const char *spec_version, PxHarmovelaTransport transport, void *ctx);

char *px_harmovela_envelope(PxArena *arena, const PxHarmovelaSink *sink,
    const PxEvent *event);

bool px_harmovela_emit(PxArena *arena, const PxHarmovelaSink *sink,
    const PxEvent *event, const char **error);

#endif
