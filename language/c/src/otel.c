#include "otel.h"

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static uint64_t fnv1a(const char *text, uint64_t seed) {
    uint64_t value = seed;
    const unsigned char *cursor = (const unsigned char *)text;
    while (*cursor != '\0') {
        value ^= (uint64_t)*cursor;
        value *= 1099511628211ULL;
        cursor++;
    }
    return value;
}

static void hex64(uint64_t value, char *buffer) {
    snprintf(buffer, 17, "%016" PRIx64, value);
}

static PxValue *attribute(PxArena *arena, const char *key, const char *value) {
    PxValue *object = px_obj(arena);
    px_obj_set(arena, object, "key", px_str(arena, key));
    PxValue *wrapped = px_obj(arena);
    px_obj_set(arena, wrapped, "stringValue", px_str(arena, value));
    px_obj_set(arena, object, "value", wrapped);
    return object;
}

static char *text_value(PxArena *arena, PxValue *value) {
    if (value != NULL && value->type == PX_STR) {
        return value->as.string;
    }
    return px_stringify(arena, value);
}

PxOtelSink px_otel_sink(const char *endpoint, const char *service_name,
        PxOtelTransport transport, void *ctx) {
    PxOtelSink sink;
    sink.endpoint = endpoint;
    sink.service_name = service_name;
    sink.allowed_data_keys = NULL;
    sink.allowed_data_key_count = 0;
    sink.transport = transport;
    sink.ctx = ctx;
    return sink;
}

char *px_otel_payload(PxArena *arena, const PxOtelSink *sink,
        const PxEvent *event) {
    if (arena == NULL || sink == NULL || event == NULL) {
        return NULL;
    }
    PxValue *data = event->data != NULL && event->data->type == PX_OBJ
        ? event->data : px_obj(arena);
    char nanos[32];
    struct timespec now;
    long long stamp;
    if (timespec_get(&now, TIME_UTC) == TIME_UTC) {
        stamp = (long long)now.tv_sec * 1000000000LL + (long long)now.tv_nsec;
    } else {
        stamp = (long long)time(NULL) * 1000000000LL;
    }
    snprintf(nanos, sizeof(nanos), "%lld", stamp);

    char key[4096];
    snprintf(key, sizeof(key), "%s|%s|%s|%s",
        event->session_id == NULL ? "" : event->session_id,
        event->run_id == NULL ? "" : event->run_id,
        event->kind == NULL ? "" : event->kind,
        px_stringify(arena, data));
    char trace[33];
    char span[17];
    hex64(fnv1a(key, 0xcbf29ce484222325ULL), trace);
    hex64(fnv1a(key, 0x84222325cbf29ce4ULL), trace + 16);
    trace[32] = '\0';
    char span_key[4200];
    snprintf(span_key, sizeof(span_key), "%s|span", key);
    hex64(fnv1a(span_key, 0x100000001b3ULL), span);

    PxValue *attributes = px_arr(arena);
    px_arr_push(arena, attributes,
        attribute(arena, "praxo.event.type",
            event->kind == NULL ? "" : event->kind));
    if (event->session_id != NULL && event->session_id[0] != '\0') {
        px_arr_push(arena, attributes,
            attribute(arena, "praxo.session.id", event->session_id));
    }
    if (event->run_id != NULL && event->run_id[0] != '\0') {
        px_arr_push(arena, attributes,
            attribute(arena, "praxo.run.id", event->run_id));
    }
    px_arr_push(arena, attributes, attribute(arena, "praxo.event.at", nanos));
    for (size_t index = 0; index < sink->allowed_data_key_count; index++) {
        const char *name = sink->allowed_data_keys[index];
        PxValue *value = px_obj_get(data, name);
        if (value == NULL) {
            continue;
        }
        char data_key[256];
        snprintf(data_key, sizeof(data_key), "praxo.event.data.%s", name);
        px_arr_push(arena, attributes,
            attribute(arena, data_key, text_value(arena, value)));
    }

    PxValue *span_object = px_obj(arena);
    px_obj_set(arena, span_object, "traceId", px_str(arena, trace));
    px_obj_set(arena, span_object, "spanId", px_str(arena, span));
    char name[256];
    snprintf(name, sizeof(name), "praxo.%s",
        event->kind == NULL ? "" : event->kind);
    px_obj_set(arena, span_object, "name", px_str(arena, name));
    px_obj_set(arena, span_object, "kind", px_num(arena, 1.0));
    px_obj_set(arena, span_object, "startTimeUnixNano", px_str(arena, nanos));
    px_obj_set(arena, span_object, "endTimeUnixNano", px_str(arena, nanos));
    px_obj_set(arena, span_object, "attributes", attributes);

    PxValue *scope = px_obj(arena);
    px_obj_set(arena, scope, "name", px_str(arena, "praxo-core"));
    PxValue *spans = px_arr(arena);
    px_arr_push(arena, spans, span_object);
    PxValue *scope_span = px_obj(arena);
    px_obj_set(arena, scope_span, "scope", scope);
    px_obj_set(arena, scope_span, "spans", spans);
    PxValue *scope_spans = px_arr(arena);
    px_arr_push(arena, scope_spans, scope_span);

    PxValue *resource_attributes = px_arr(arena);
    px_arr_push(arena, resource_attributes, attribute(arena, "service.name",
        sink->service_name == NULL ? "praxo-core" : sink->service_name));
    PxValue *resource = px_obj(arena);
    px_obj_set(arena, resource, "attributes", resource_attributes);
    PxValue *resource_span = px_obj(arena);
    px_obj_set(arena, resource_span, "resource", resource);
    px_obj_set(arena, resource_span, "scopeSpans", scope_spans);
    PxValue *resource_spans = px_arr(arena);
    px_arr_push(arena, resource_spans, resource_span);
    PxValue *root = px_obj(arena);
    px_obj_set(arena, root, "resourceSpans", resource_spans);
    return px_stringify(arena, root);
}

bool px_otel_emit(PxArena *arena, const PxOtelSink *sink,
        const PxEvent *event, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (sink == NULL || sink->endpoint == NULL || sink->endpoint[0] == '\0'
            || sink->transport == NULL) {
        if (error != NULL) {
            *error = "OTEL_TRANSPORT";
        }
        return false;
    }
    char *payload = px_otel_payload(arena, sink, event);
    if (payload == NULL) {
        if (error != NULL) {
            *error = "OTEL_JSON";
        }
        return false;
    }
    PxOtelResponse response;
    response.status = 0;
    response.body = NULL;
    const char *transport_error = NULL;
    if (!sink->transport("POST", sink->endpoint, "application/json", payload,
            sink->ctx, &response, &transport_error)) {
        if (error != NULL) {
            *error = transport_error == NULL ? "OTEL_TRANSPORT" : transport_error;
        }
        return false;
    }
    if (response.status < 200 || response.status >= 300) {
        if (error != NULL) {
            *error = "OTEL_HTTP";
        }
        return false;
    }
    return true;
}
