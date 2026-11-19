#include "gemini.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *str_or_empty(const char *value) {
    return value == NULL ? "" : value;
}

static PxValue *message_parts(PxArena *arena, PxValue *message) {
    PxValue *parts = px_arr(arena);
    const char *text = px_get_str(message, "content");
    if (text != NULL && text[0] != '\0') {
        PxValue *part = px_obj(arena);
        px_obj_set(arena, part, "text", px_str(arena, text));
        px_arr_push(arena, parts, part);
    }
    PxValue *blocks = px_obj_get(message, "contentBlocks");
    if (blocks != NULL && blocks->type == PX_ARR) {
        for (size_t index = 0; index < blocks->as.array.len; index++) {
            PxValue *block = blocks->as.array.items[index];
            const char *kind = px_get_str(block, "type");
            const char *value = px_get_str(block, "text");
            if (kind != NULL && strcmp(kind, "text") == 0
                    && value != NULL && value[0] != '\0') {
                PxValue *part = px_obj(arena);
                px_obj_set(arena, part, "text", px_str(arena, value));
                px_arr_push(arena, parts, part);
            }
        }
    }
    PxValue *calls = px_obj_get(message, "toolCalls");
    if (calls != NULL && calls->type == PX_ARR) {
        for (size_t index = 0; index < calls->as.array.len; index++) {
            PxValue *call = calls->as.array.items[index];
            PxValue *arguments = px_obj_get(call, "arguments");
            PxValue *function = px_obj(arena);
            px_obj_set(arena, function, "name", px_str(arena,
                str_or_empty(px_get_str(call, "name"))));
            px_obj_set(arena, function, "args",
                arguments == NULL ? px_obj(arena) : arguments);
            PxValue *part = px_obj(arena);
            px_obj_set(arena, part, "functionCall", function);
            px_arr_push(arena, parts, part);
        }
    }
    return parts;
}

PxValue *px_gemini_request(PxArena *arena, const PxGemini *adapter,
        PxValue *messages, PxValue *tools, const char **error) {
    if (error != NULL) *error = NULL;
    if (adapter == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    PxValue *system = px_arr(arena);
    PxValue *contents = px_arr(arena);
    PxValue *pending = px_arr(arena);
    if (messages != NULL && messages->type == PX_ARR) {
        for (size_t index = 0; index < messages->as.array.len; index++) {
            PxValue *message = messages->as.array.items[index];
            const char *role = px_get_str(message, "role");
            if (role == NULL) {
                if (error != NULL) *error = "PROVIDER_JSON";
                return NULL;
            }
            if (strcmp(role, "system") == 0) {
                const char *content = px_get_str(message, "content");
                if (content != NULL && content[0] != '\0') {
                    PxValue *part = px_obj(arena);
                    px_obj_set(arena, part, "text", px_str(arena, content));
                    px_arr_push(arena, system, part);
                }
                continue;
            }
            if (strcmp(role, "tool") == 0) {
                PxValue *response = px_obj(arena);
                px_obj_set(arena, response, "result", px_str(arena,
                    str_or_empty(px_get_str(message, "content"))));
                PxValue *function = px_obj(arena);
                px_obj_set(arena, function, "name", px_str(arena,
                    str_or_empty(px_get_str(message, "toolId"))));
                px_obj_set(arena, function, "response", response);
                PxValue *part = px_obj(arena);
                px_obj_set(arena, part, "functionResponse", function);
                px_arr_push(arena, pending, part);
                continue;
            }
            if (pending->as.array.len > 0) {
                PxValue *group = px_obj(arena);
                px_obj_set(arena, group, "role", px_str(arena, "user"));
                px_obj_set(arena, group, "parts", pending);
                pending = px_arr(arena);
                px_arr_push(arena, contents, group);
            }
            PxValue *parts = message_parts(arena, message);
            if (parts->as.array.len > 0) {
                PxValue *group = px_obj(arena);
                px_obj_set(arena, group, "role", px_str(arena,
                    strcmp(role, "assistant") == 0 ? "model" : "user"));
                px_obj_set(arena, group, "parts", parts);
                px_arr_push(arena, contents, group);
            }
        }
    }
    if (pending->as.array.len > 0) {
        PxValue *group = px_obj(arena);
        px_obj_set(arena, group, "role", px_str(arena, "user"));
        px_obj_set(arena, group, "parts", pending);
        px_arr_push(arena, contents, group);
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "contents", contents);
    if (system->as.array.len > 0) {
        PxValue *instruction = px_obj(arena);
        px_obj_set(arena, instruction, "parts", system);
        px_obj_set(arena, out, "system_instruction", instruction);
    }
    if (tools != NULL && tools->type == PX_ARR && tools->as.array.len > 0) {
        PxValue *declarations = px_arr(arena);
        for (size_t index = 0; index < tools->as.array.len; index++) {
            PxValue *tool = tools->as.array.items[index];
            PxValue *parameters = px_obj_get(tool, "parameters");
            PxValue *item = px_obj(arena);
            px_obj_set(arena, item, "name", px_str(arena,
                str_or_empty(px_get_str(tool, "name"))));
            px_obj_set(arena, item, "description", px_str(arena,
                str_or_empty(px_get_str(tool, "description"))));
            px_obj_set(arena, item, "parameters",
                parameters == NULL ? px_obj(arena) : parameters);
            px_arr_push(arena, declarations, item);
        }
        PxValue *group = px_obj(arena);
        px_obj_set(arena, group, "functionDeclarations", declarations);
        PxValue *tools_array = px_arr(arena);
        px_arr_push(arena, tools_array, group);
        px_obj_set(arena, out, "tools", tools_array);
        PxValue *calling = px_obj(arena);
        px_obj_set(arena, calling, "mode", px_str(arena, "AUTO"));
        PxValue *config = px_obj(arena);
        px_obj_set(arena, config, "functionCallingConfig", calling);
        px_obj_set(arena, out, "toolConfig", config);
    }
    return out;
}

PxValue *px_gemini_parse_response(PxArena *arena, const char *text,
        const char **error) {
    if (error != NULL) *error = NULL;
    PxValue *data = px_parse(arena, text == NULL ? "" : text);
    if (data == NULL || data->type != PX_OBJ) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    if (px_obj_get(data, "error") != NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    PxValue *candidates = px_obj_get(data, "candidates");
    PxValue *candidate = candidates != NULL && candidates->type == PX_ARR
        && candidates->as.array.len > 0 ? candidates->as.array.items[0] : NULL;
    if (candidate == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    PxValue *content = px_obj_get(candidate, "content");
    PxValue *parts = content == NULL ? NULL : px_obj_get(content, "parts");
    size_t text_length = 0;
    if (parts != NULL && parts->type == PX_ARR) {
        for (size_t index = 0; index < parts->as.array.len; index++) {
            const char *value = px_get_str(parts->as.array.items[index], "text");
            if (value != NULL) text_length += strlen(value);
        }
    }
    char *joined = px_arena_alloc(arena, text_length + 1);
    PxValue *calls = px_arr(arena);
    if (joined == NULL) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    joined[0] = '\0';
    if (parts != NULL && parts->type == PX_ARR) {
        for (size_t index = 0; index < parts->as.array.len; index++) {
            PxValue *part = parts->as.array.items[index];
            const char *value = px_get_str(part, "text");
            if (value != NULL) strcat(joined, value);
            PxValue *call = px_obj_get(part, "functionCall");
            if (call != NULL && call->type == PX_OBJ) {
                PxValue *args = px_obj_get(call, "args");
                PxValue *item = px_obj(arena);
                px_obj_set(arena, item, "id", px_str(arena, "call-"));
                px_obj_set(arena, item, "name", px_str(arena,
                    str_or_empty(px_get_str(call, "name"))));
                px_obj_set(arena, item, "arguments",
                    args == NULL ? px_obj(arena) : args);
                px_arr_push(arena, calls, item);
            }
        }
    }
    PxValue *usage = px_obj_get(data, "usageMetadata");
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content", px_str(arena, joined));
    px_obj_set(arena, out, "toolCalls", calls);
    px_obj_set(arena, out, "inputTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "promptTokenCount", 0)));
    px_obj_set(arena, out, "outputTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "candidatesTokenCount", 0)));
    px_obj_set(arena, out, "cachedTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "cachedContentTokenCount", 0)));
    const char *finish = px_get_str(candidate, "finishReason");
    if (finish != NULL) px_obj_set(arena, out, "finishReason", px_str(arena, finish));
    return out;
}

typedef struct {
    char *id;
    size_t id_length;
    size_t id_capacity;
    char *name;
    size_t name_length;
    size_t name_capacity;
    char *arguments;
    size_t arguments_length;
    size_t arguments_capacity;
} PxGeminiStreamCall;

static int gemini_append_text(char **buffer, size_t *length, size_t *capacity,
        const char *text) {
    if (text == NULL) return 1;
    size_t extra = strlen(text);
    if (*length + extra + 1 > *capacity) {
        size_t next = *capacity == 0 ? 64 : *capacity;
        while (next < *length + extra + 1) next *= 2;
        char *grown = realloc(*buffer, next);
        if (grown == NULL) return 0;
        *buffer = grown;
        *capacity = next;
    }
    memcpy(*buffer + *length, text, extra);
    *length += extra;
    (*buffer)[*length] = '\0';
    return 1;
}

static PxValue *gemini_parse_stream(PxArena *arena, const char *text,
        const char *(*on_delta)(const char *delta, void *ctx), void *ctx,
        const char **error) {
    char *copy = px_arena_strdup(arena, text == NULL ? "" : text);
    char *content = NULL;
    size_t content_length = 0;
    size_t content_capacity = 0;
    PxGeminiStreamCall calls[8];
    memset(calls, 0, sizeof(calls));
    size_t call_count = 0;
    double input_tokens = 0;
    double output_tokens = 0;
    double cached_tokens = 0;
    const char *finish_reason = NULL;
    const char *stream_error = NULL;
    for (char *line = strtok(copy, "\n"); line != NULL;
            line = strtok(NULL, "\n")) {
        size_t length = strlen(line);
        if (length > 0 && line[length - 1] == '\r') line[length - 1] = '\0';
        if (strncmp(line, "data:", 5) != 0) continue;
        char *data = line + 5;
        while (*data == ' ') data++;
        if (data[0] == '\0' || strcmp(data, "[DONE]") == 0) continue;
        PxValue *event = px_parse(arena, data);
        if (event == NULL || event->type != PX_OBJ) {
            stream_error = "MODEL_STREAM";
            break;
        }
        if (px_obj_get(event, "error") != NULL) {
            stream_error = "MODEL_STREAM";
            break;
        }
        PxValue *usage = px_obj_get(event, "usageMetadata");
        if (usage != NULL && usage->type == PX_OBJ) {
            input_tokens = px_get_num(usage, "promptTokenCount", input_tokens);
            output_tokens = px_get_num(usage, "candidatesTokenCount",
                output_tokens);
            cached_tokens = px_get_num(usage, "cachedContentTokenCount",
                cached_tokens);
        }
        PxValue *candidates = px_obj_get(event, "candidates");
        if (candidates == NULL || candidates->type != PX_ARR
                || candidates->as.array.len == 0) {
            continue;
        }
        PxValue *candidate = candidates->as.array.items[0];
        if (candidate == NULL || candidate->type != PX_OBJ) continue;
        const char *reason = px_get_str(candidate, "finishReason");
        if (reason != NULL) finish_reason = reason;
        PxValue *content_value = px_obj_get(candidate, "content");
        PxValue *parts = content_value == NULL ? NULL
            : px_obj_get(content_value, "parts");
        if (parts == NULL || parts->type != PX_ARR) continue;
        for (size_t index = 0; index < parts->as.array.len; index++) {
            PxValue *part = parts->as.array.items[index];
            if (part == NULL || part->type != PX_OBJ) continue;
            const char *piece = px_get_str(part, "text");
            if (piece != NULL && piece[0] != '\0') {
                if (!gemini_append_text(&content, &content_length,
                        &content_capacity, piece)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                if (on_delta != NULL) {
                    const char *callback_error = on_delta(piece, ctx);
                    if (callback_error != NULL) {
                        stream_error = callback_error;
                        break;
                    }
                }
            }
            PxValue *call = px_obj_get(part, "functionCall");
            if (call != NULL && call->type == PX_OBJ && call_count < 8) {
                PxValue *args = px_obj_get(call, "args");
                PxGeminiStreamCall *slot = &calls[call_count];
                const char *name = px_get_str(call, "name");
                if (!gemini_append_text(&slot->name, &slot->name_length,
                        &slot->name_capacity, name)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                char id[32];
                snprintf(id, sizeof(id), "call-%zu", call_count + 1);
                if (!gemini_append_text(&slot->id, &slot->id_length,
                        &slot->id_capacity, id)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                if (args != NULL && args->type == PX_OBJ) {
                    const char *raw = px_stringify(arena, args);
                    if (!gemini_append_text(&slot->arguments,
                            &slot->arguments_length, &slot->arguments_capacity,
                            raw)) {
                        stream_error = "MODEL_STREAM";
                        break;
                    }
                }
                call_count++;
            }
        }
        if (stream_error != NULL) break;
    }
    if (stream_error != NULL) {
        if (error != NULL) *error = stream_error;
        return NULL;
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content",
        px_str(arena, content == NULL ? "" : content));
    PxValue *tool_calls = px_arr(arena);
    for (size_t index = 0; index < call_count; index++) {
        PxValue *call = px_obj(arena);
        px_obj_set(arena, call, "id", px_str(arena,
            calls[index].id == NULL ? "" : calls[index].id));
        px_obj_set(arena, call, "name", px_str(arena,
            calls[index].name == NULL ? "" : calls[index].name));
        PxValue *arguments = calls[index].arguments == NULL
            ? px_obj(arena) : px_parse(arena, calls[index].arguments);
        if (arguments == NULL || arguments->type != PX_OBJ) {
            if (error != NULL) *error = "PROVIDER_JSON";
            return NULL;
        }
        px_obj_set(arena, call, "arguments", arguments);
        px_arr_push(arena, tool_calls, call);
    }
    px_obj_set(arena, out, "toolCalls", tool_calls);
    px_obj_set(arena, out, "inputTokens", px_num(arena, input_tokens));
    px_obj_set(arena, out, "outputTokens", px_num(arena, output_tokens));
    px_obj_set(arena, out, "cachedTokens", px_num(arena, cached_tokens));
    if (finish_reason != NULL) {
        px_obj_set(arena, out, "finishReason", px_str(arena, finish_reason));
    }
    for (size_t index = 0; index < call_count; index++) {
        free(calls[index].id);
        free(calls[index].name);
        free(calls[index].arguments);
    }
    free(content);
    return out;
}

const char *px_gemini_stream_url(PxArena *arena, const PxGemini *adapter) {
    const char *base = adapter->base_url == NULL
        ? "https://generativelanguage.googleapis.com" : adapter->base_url;
    const char *model = str_or_empty(adapter->model);
    size_t length = strlen(base);
    while (length > 0 && base[length - 1] == '/') length--;
    size_t suffix = strlen("/v1beta/models/:streamGenerateContent?alt=sse")
        + strlen(model);
    char *url = px_arena_alloc(arena, length + suffix + 1);
    if (url == NULL) return NULL;
    memcpy(url, base, length);
    snprintf(url + length, suffix + 1,
        "/v1beta/models/%s:streamGenerateContent?alt=sse", model);
    return url;
}

PxValue *px_gemini_generate_stream(PxArena *arena, PxValue *messages,
        PxValue *tools, const char *(*on_delta)(const char *delta, void *ctx),
        void *ctx, const char **error) {
    if (error != NULL) *error = NULL;
    PxGemini *adapter = ctx;
    if (adapter == NULL || adapter->transport == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    const char *request_error = NULL;
    PxValue *payload = px_gemini_request(arena, adapter, messages, tools,
        &request_error);
    if (payload == NULL || request_error != NULL) {
        if (error != NULL) *error = request_error == NULL
            ? "PROVIDER_JSON" : request_error;
        return NULL;
    }
    char *body = px_stringify(arena, payload);
    if (body == NULL) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    const char *url = px_gemini_stream_url(arena, adapter);
    if (url == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    const char *response = adapter->transport(url, body, adapter->api_key,
        adapter->transport_ctx, &request_error);
    if (request_error != NULL || response == NULL) {
        if (error != NULL) *error = request_error == NULL
            ? "PROVIDER_HTTP" : request_error;
        return NULL;
    }
    return gemini_parse_stream(arena, response, on_delta, ctx, error);
}

const char *px_gemini_url(PxArena *arena, const PxGemini *adapter) {
    const char *base = adapter->base_url == NULL
        ? "https://generativelanguage.googleapis.com" : adapter->base_url;
    const char *model = str_or_empty(adapter->model);
    size_t length = strlen(base);
    while (length > 0 && base[length - 1] == '/') length--;
    size_t suffix = strlen("/v1beta/models/:generateContent") + strlen(model);
    char *url = px_arena_alloc(arena, length + suffix + 1);
    if (url == NULL) return NULL;
    memcpy(url, base, length);
    snprintf(url + length, suffix + 1, "/v1beta/models/%s:generateContent", model);
    return url;
}

PxValue *px_gemini_generate(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    PxGemini *adapter = ctx;
    const char *error = NULL;
    if (adapter == NULL || adapter->transport == NULL) return NULL;
    PxValue *payload = px_gemini_request(arena, adapter, messages, tools, &error);
    if (payload == NULL) return NULL;
    char *body = px_stringify(arena, payload);
    if (body == NULL) return NULL;
    const char *url = px_gemini_url(arena, adapter);
    if (url == NULL) return NULL;
    const char *response = adapter->transport(url, body, adapter->api_key,
        adapter->transport_ctx, &error);
    if (response == NULL) return NULL;
    return px_gemini_parse_response(arena, response, &error);
}
