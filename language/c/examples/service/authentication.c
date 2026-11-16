#include "authentication.h"

#include "praxo.h"

#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

static const char *or_empty(const char *text) {
    return text == NULL ? "" : text;
}

static char *duplicate_text(const char *text) {
    size_t size = strlen(text);
    char *out = malloc(size + 1);
    if (out == NULL) {
        return NULL;
    }
    memcpy(out, text, size + 1);
    return out;
}

static bool unreserved(unsigned char ch) {
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
           (ch >= '0' && ch <= '9') || ch == '-' || ch == '.' ||
           ch == '_' || ch == '~';
}

static size_t encoded_length(const char *text) {
    size_t length = 0;
    for (const unsigned char *cursor = (const unsigned char *)text;
            *cursor != '\0'; cursor++) {
        length += unreserved(*cursor) ? 1 : 3;
    }
    return length;
}

static char *encode_into(char *out, const char *text) {
    static const char hex[] = "0123456789ABCDEF";
    for (const unsigned char *cursor = (const unsigned char *)text;
            *cursor != '\0'; cursor++) {
        if (unreserved(*cursor)) {
            *out++ = (char)*cursor;
        } else {
            *out++ = '%';
            *out++ = hex[*cursor >> 4];
            *out++ = hex[*cursor & 0x0F];
        }
    }
    return out;
}

static char *build_form(const char *const *keys, const char *const *values,
        size_t count) {
    size_t size = 1;
    for (size_t index = 0; index < count; index++) {
        if (index > 0) {
            size += 1;
        }
        size += encoded_length(keys[index]) + 1 + encoded_length(values[index]);
    }
    char *form = malloc(size);
    if (form == NULL) {
        return NULL;
    }
    char *out = form;
    for (size_t index = 0; index < count; index++) {
        if (index > 0) {
            *out++ = '&';
        }
        out = encode_into(out, keys[index]);
        *out++ = '=';
        out = encode_into(out, values[index]);
    }
    *out = '\0';
    return form;
}

static char *basic_authorization(const char *client_id,
        const char *client_secret) {
    const char *id = or_empty(client_id);
    if (id[0] == '\0') {
        return NULL;
    }
    const char *secret = or_empty(client_secret);
    size_t id_length = strlen(id);
    size_t secret_length = strlen(secret);
    size_t raw_length = id_length + 1 + secret_length;
    unsigned char *raw = malloc(raw_length);
    if (raw == NULL) {
        return NULL;
    }
    memcpy(raw, id, id_length);
    raw[id_length] = ':';
    memcpy(raw + id_length + 1, secret, secret_length);
    size_t encoded_length = ((raw_length + 2) / 3) * 4;
    char *out = malloc(6 + encoded_length + 1);
    if (out == NULL) {
        free(raw);
        return NULL;
    }
    static const char table[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    memcpy(out, "Basic ", 6);
    size_t position = 6;
    for (size_t index = 0; index < raw_length; index += 3) {
        size_t remaining = raw_length - index;
        unsigned int first = raw[index];
        unsigned int second = remaining > 1 ? raw[index + 1] : 0;
        unsigned int third = remaining > 2 ? raw[index + 2] : 0;
        out[position++] = table[first >> 2];
        out[position++] = table[((first & 0x03) << 4) | (second >> 4)];
        out[position++] = remaining > 1
            ? table[((second & 0x0F) << 2) | (third >> 6)]
            : '=';
        out[position++] = remaining > 2 ? table[third & 0x3F] : '=';
    }
    out[position] = '\0';
    free(raw);
    return out;
}

static char *trim_copy(const char *text) {
    if (text == NULL) {
        return NULL;
    }
    while (*text == ' ' || *text == '\t' || *text == '\n' || *text == '\r') {
        text++;
    }
    const char *end = text + strlen(text);
    while (end > text && (end[-1] == ' ' || end[-1] == '\t' ||
            end[-1] == '\n' || end[-1] == '\r')) {
        end--;
    }
    size_t length = (size_t)(end - text);
    char *out = malloc(length + 1);
    if (out == NULL) {
        return NULL;
    }
    memcpy(out, text, length);
    out[length] = '\0';
    return out;
}

void service_auth_introspector_init(ServiceAuthIntrospector *auth,
        ServiceAuthTransport transport, void *context,
        const char *endpoint, const char *client_id,
        const char *client_secret, const char *tenant_claim) {
    if (auth == NULL) {
        return;
    }
    auth->transport = transport;
    auth->context = context;
    auth->endpoint = endpoint;
    auth->client_id = or_empty(client_id);
    auth->client_secret = or_empty(client_secret);
    auth->tenant_claim = tenant_claim != NULL && tenant_claim[0] != '\0'
        ? tenant_claim
        : "tenant";
}

void service_auth_principal_free(ServiceAuthPrincipal *principal) {
    if (principal == NULL) {
        return;
    }
    free(principal->subject);
    free(principal->tenant);
    principal->subject = NULL;
    principal->tenant = NULL;
    principal->expires = 0;
}

bool service_auth_introspect(const ServiceAuthIntrospector *auth,
        const char *authorization, int64_t now,
        ServiceAuthPrincipal *principal) {
    if (principal != NULL) {
        principal->subject = NULL;
        principal->tenant = NULL;
        principal->expires = 0;
    }
    if (auth == NULL || principal == NULL || auth->transport == NULL ||
            auth->endpoint == NULL || authorization == NULL) {
        return false;
    }
    if (strncmp(authorization, "Bearer ", 7) != 0) {
        return false;
    }
    char *token = trim_copy(authorization + 7);
    if (token == NULL || token[0] == '\0') {
        free(token);
        return false;
    }
    const char *tenant_claim = auth->tenant_claim;
    if (tenant_claim == NULL || tenant_claim[0] == '\0') {
        tenant_claim = "tenant";
    }
    const char *keys[] = {"token", "client_id", "client_secret"};
    const char *values[] = {token, or_empty(auth->client_id),
                            or_empty(auth->client_secret)};
    char *form = build_form(keys, values, 3);
    if (form == NULL) {
        free(token);
        return false;
    }
    char *header = basic_authorization(auth->client_id, auth->client_secret);
    int status = 0;
    const char *body = NULL;
    int transport_result = auth->transport(auth->endpoint, form, header,
            &status, &body, auth->context);
    free(form);
    free(header);
    free(token);
    if (transport_result != 0 || status != 200 || body == NULL) {
        return false;
    }
    PxArena arena;
    px_arena_init(&arena);
    PxValue *payload = px_parse(&arena, body);
    bool authenticated = false;
    if (payload != NULL && payload->type == PX_OBJ) {
        PxValue *active = px_obj_get(payload, "active");
        const char *subject = px_get_str(payload, "sub");
        const char *tenant = px_get_str(payload, tenant_claim);
        PxValue *expires = px_obj_get(payload, "exp");
        if (active != NULL && active->type == PX_BOOL &&
                active->as.boolean && subject != NULL &&
                subject[0] != '\0' && tenant != NULL &&
                tenant[0] != '\0' && expires != NULL &&
                expires->type == PX_NUM && isfinite(expires->as.number) &&
                floor(expires->as.number) == expires->as.number &&
                expires->as.number > (double)now &&
                expires->as.number >= -9223372036854775808.0 &&
                expires->as.number < 9223372036854775808.0) {
            char *subject_copy = duplicate_text(subject);
            char *tenant_copy = duplicate_text(tenant);
            if (subject_copy != NULL && tenant_copy != NULL) {
                principal->subject = subject_copy;
                principal->tenant = tenant_copy;
                principal->expires = (int64_t)expires->as.number;
                authenticated = true;
            } else {
                free(subject_copy);
                free(tenant_copy);
            }
        }
    }
    px_arena_free(&arena);
    return authenticated;
}

void service_auth_revoker_init(ServiceAuthRevoker *client,
        ServiceAuthTransport transport, void *context,
        const char *endpoint, const char *client_id,
        const char *client_secret) {
    if (client == NULL) {
        return;
    }
    client->transport = transport;
    client->context = context;
    client->endpoint = endpoint;
    client->client_id = or_empty(client_id);
    client->client_secret = or_empty(client_secret);
}

bool service_auth_revoke(const ServiceAuthRevoker *client,
        const char *token) {
    if (client == NULL || client->transport == NULL ||
            client->endpoint == NULL || token == NULL || token[0] == '\0') {
        return false;
    }
    const char *keys[] = {"token", "token_type_hint", "client_id",
                          "client_secret"};
    const char *values[] = {token, "access_token", or_empty(client->client_id),
                            or_empty(client->client_secret)};
    char *form = build_form(keys, values, 4);
    if (form == NULL) {
        return false;
    }
    char *header = basic_authorization(client->client_id,
            client->client_secret);
    int status = 0;
    const char *body = NULL;
    int transport_result = client->transport(client->endpoint, form, header,
            &status, &body, client->context);
    free(form);
    free(header);
    return transport_result == 0 && status == 200;
}
