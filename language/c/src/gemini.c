#include "gemini.h"

#include <stdio.h>
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
