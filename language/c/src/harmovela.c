#include "harmovela.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static long long default_clock(void *ctx) {
    (void)ctx;
    struct timespec now;
    if (timespec_get(&now, TIME_UTC) != TIME_UTC) {
        return (long long)time(NULL) * 1000000000LL;
    }
    return (long long)now.tv_sec * 1000000000LL + (long long)now.tv_nsec;
}

PxHarmovelaSink px_harmovela_sink(const char *base_url, const char *source,
        const char *spec_version, PxHarmovelaTransport transport, void *ctx) {
    PxHarmovelaSink sink;
    sink.base_url = base_url;
    sink.source = source;
    sink.spec_version = spec_version;
    sink.transport = transport;
    sink.transport_ctx = ctx;
    sink.clock = default_clock;
    sink.clock_ctx = NULL;
    return sink;
}

static const char *default_source(const PxHarmovelaSink *sink) {
    if (sink->source == NULL || sink->source[0] == '\0') {
        return "praxo-core";
    }
    return sink->source;
}

static const char *default_spec(const PxHarmovelaSink *sink) {
    if (sink->spec_version == NULL || sink->spec_version[0] == '\0') {
        return "0.2";
    }
    return sink->spec_version;
}

static char *created_at(PxArena *arena, long long epoch_nanos) {
    long long seconds = epoch_nanos / 1000000000LL;
    long long nanos = epoch_nanos % 1000000000LL;
    if (nanos < 0) {
        nanos += 1000000000LL;
        seconds -= 1;
    }
    time_t instant = (time_t)seconds;
    struct tm value;
#ifdef _WIN32
    gmtime_s(&value, &instant);
#else
    gmtime_r(&instant, &value);
#endif
    char buffer[64];
    snprintf(buffer, sizeof(buffer),
        "%04d-%02d-%02dT%02d:%02d:%02d.%09lldZ",
        value.tm_year + 1900, value.tm_mon + 1, value.tm_mday,
        value.tm_hour, value.tm_min, value.tm_sec, nanos);
    return px_arena_strdup(arena, buffer);
}

char *px_harmovela_envelope(PxArena *arena, const PxHarmovelaSink *sink,
        const PxEvent *event) {
    if (arena == NULL || sink == NULL || event == NULL) {
        return NULL;
    }
    long long (*clock)(void *) = sink->clock == NULL ? default_clock : sink->clock;
    long long epoch_nanos = clock(sink->clock_ctx);
    const char *prefix = "event";
    if (event->run_id != NULL && event->run_id[0] != '\0') {
        prefix = event->run_id;
    } else if (event->session_id != NULL && event->session_id[0] != '\0') {
        prefix = event->session_id;
    }
    char identifier[256];
    snprintf(identifier, sizeof(identifier), "%s-%lld", prefix, epoch_nanos);
    PxValue *payload = px_obj(arena);
    if (event->data != NULL && event->data->type == PX_OBJ) {
        for (size_t index = 0; index < event->data->as.object.len; index++) {
            px_obj_set(arena, payload, event->data->as.object.pairs[index].key,
                event->data->as.object.pairs[index].value);
        }
    }
    if (event->session_id != NULL && event->session_id[0] != '\0') {
        px_obj_set(arena, payload, "session_id", px_str(arena, event->session_id));
    }
    if (event->run_id != NULL && event->run_id[0] != '\0') {
        px_obj_set(arena, payload, "run_id", px_str(arena, event->run_id));
    }
    PxValue *envelope = px_obj(arena);
    px_obj_set(arena, envelope, "spec_version", px_str(arena, default_spec(sink)));
    px_obj_set(arena, envelope, "id", px_str(arena, identifier));
    px_obj_set(arena, envelope, "type", px_str(arena,
        event->kind == NULL ? "" : event->kind));
    px_obj_set(arena, envelope, "source", px_str(arena, default_source(sink)));
    px_obj_set(arena, envelope, "created_at", px_str(arena,
        created_at(arena, epoch_nanos)));
    px_obj_set(arena, envelope, "payload", payload);
    return px_stringify(arena, envelope);
}

static void set_error(PxArena *arena, const char **error, const char *message) {
    if (error != NULL) {
        *error = px_arena_strdup(arena, message);
    }
}

bool px_harmovela_emit(PxArena *arena, const PxHarmovelaSink *sink,
        const PxEvent *event, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (sink == NULL || sink->base_url == NULL || sink->base_url[0] == '\0') {
        set_error(arena, error, "harmovela: base URL is required");
        return false;
    }
    char *body = px_harmovela_envelope(arena, sink, event);
    if (body == NULL) {
        set_error(arena, error, "harmovela: cannot encode envelope");
        return false;
    }
    size_t length = strlen(sink->base_url);
    while (length > 0 && sink->base_url[length - 1] == '/') {
        length--;
    }
    char *url = px_arena_alloc(arena, length + 8);
    if (url == NULL) {
        set_error(arena, error, "harmovela: allocation failed");
        return false;
    }
    memcpy(url, sink->base_url, length);
    memcpy(url + length, "/events", 8);
    if (sink->transport == NULL) {
        set_error(arena, error,
            "harmovela: inject a transport; no HTTP client is bundled");
        return false;
    }
    PxHarmovelaResponse response;
    response.status = 0;
    response.body = "";
    const char *transport_error = NULL;
    if (!sink->transport("POST", url, "application/json", body,
            sink->transport_ctx, &response, &transport_error)) {
        set_error(arena, error, transport_error == NULL
            ? "harmovela: transport failed" : transport_error);
        return false;
    }
    if (response.status < 200 || response.status >= 300) {
        const char *text = response.body == NULL ? "" : response.body;
        size_t text_length = strlen(text);
        if (text_length > 512) {
            text_length = 512;
        }
        char message[640];
        snprintf(message, sizeof(message), "harmovela: HTTP %d: %.*s",
            response.status, (int)text_length, text);
        set_error(arena, error, message);
        return false;
    }
    return true;
}
