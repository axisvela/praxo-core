#include "anthropic.h"

#include <string.h>

static const char *str_or_empty(const char *value) {
    return value == NULL ? "" : value;
}

static PxValue *text_content(PxArena *arena, const PxValue *message) {
    PxValue *content = px_arr(arena);
    const char *text = px_get_str(message, "content");
    if (text != NULL && text[0] != '\0') {
        PxValue *item = px_obj(arena);
        px_obj_set(arena, item, "type", px_str(arena, "text"));
        px_obj_set(arena, item, "text", px_str(arena, text));
        px_arr_push(arena, content, item);
    }
    PxValue *blocks = px_obj_get(message, "contentBlocks");
    if (blocks != NULL && blocks->type == PX_ARR) {
        for (size_t index = 0; index < blocks->as.array.len; index++) {
            PxValue *block = blocks->as.array.items[index];
            const char *kind = px_get_str(block, "type");
            const char *value = px_get_str(block, "text");
            if (kind != NULL && strcmp(kind, "text") == 0
                    && value != NULL && value[0] != '\0') {
                PxValue *item = px_obj(arena);
                px_obj_set(arena, item, "type", px_str(arena, "text"));
                px_obj_set(arena, item, "text", px_str(arena, value));
                px_arr_push(arena, content, item);
            }
        }
    }
    PxValue *calls = px_obj_get(message, "toolCalls");
    if (calls != NULL && calls->type == PX_ARR) {
        for (size_t index = 0; index < calls->as.array.len; index++) {
            PxValue *call = calls->as.array.items[index];
            PxValue *arguments = px_obj_get(call, "arguments");
            PxValue *item = px_obj(arena);
            px_obj_set(arena, item, "type", px_str(arena, "tool_use"));
            px_obj_set(arena, item, "id", px_str(arena,
                str_or_empty(px_get_str(call, "id"))));
            px_obj_set(arena, item, "name", px_str(arena,
                str_or_empty(px_get_str(call, "name"))));
            px_obj_set(arena, item, "input",
                arguments == NULL ? px_obj(arena) : arguments);
            px_arr_push(arena, content, item);
        }
    }
    return content;
}

PxValue *px_anthropic_request(PxArena *arena, const PxAnthropic *adapter,
        PxValue *messages, PxValue *tools, const char **error) {
    if (error != NULL) *error = NULL;
    if (adapter == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    PxValue *system = px_arr(arena);
    PxValue *wire_messages = px_arr(arena);
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
                    px_arr_push(arena, system, px_str(arena, content));
                }
                continue;
            }
            if (strcmp(role, "tool") == 0) {
                PxValue *item = px_obj(arena);
                px_obj_set(arena, item, "type", px_str(arena, "tool_result"));
                px_obj_set(arena, item, "tool_use_id", px_str(arena,
                    str_or_empty(px_get_str(message, "toolId"))));
                px_obj_set(arena, item, "content", px_str(arena,
                    str_or_empty(px_get_str(message, "content"))));
                px_arr_push(arena, pending, item);
                continue;
            }
            if (pending->as.array.len > 0) {
                PxValue *group = px_obj(arena);
                px_obj_set(arena, group, "role", px_str(arena, "user"));
                px_obj_set(arena, group, "content",
                    px_arr(arena));
                PxValue *target = px_obj_get(group, "content");
                for (size_t item_index = 0; item_index < pending->as.array.len;
                        item_index++) {
                    px_arr_push(arena, target, pending->as.array.items[item_index]);
                }
                pending = px_arr(arena);
                px_arr_push(arena, wire_messages, group);
            }
            PxValue *content = text_content(arena, message);
            if (content->as.array.len > 0) {
                PxValue *item = px_obj(arena);
                px_obj_set(arena, item, "role", px_str(arena, role));
                px_obj_set(arena, item, "content", content);
                px_arr_push(arena, wire_messages, item);
            }
        }
    }
    if (pending->as.array.len > 0) {
        PxValue *group = px_obj(arena);
        px_obj_set(arena, group, "role", px_str(arena, "user"));
        px_obj_set(arena, group, "content", pending);
        px_arr_push(arena, wire_messages, group);
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "model", px_str(arena, str_or_empty(adapter->model)));
    px_obj_set(arena, out, "max_tokens", px_num(arena,
        adapter->max_tokens > 0 ? adapter->max_tokens : 1024));
    px_obj_set(arena, out, "messages", wire_messages);
    if (system->as.array.len > 0) {
        size_t length = 0;
        for (size_t index = 0; index < system->as.array.len; index++) {
            length += strlen(system->as.array.items[index]->as.string);
            if (index > 0) length += 2;
        }
        char *joined = px_arena_alloc(arena, length + 1);
        if (joined == NULL) {
            if (error != NULL) *error = "PROVIDER_JSON";
            return NULL;
        }
        joined[0] = '\0';
        for (size_t index = 0; index < system->as.array.len; index++) {
            if (index > 0) strcat(joined, "\n\n");
            strcat(joined, system->as.array.items[index]->as.string);
        }
        px_obj_set(arena, out, "system", px_str(arena, joined));
    }
    if (tools != NULL && tools->type == PX_ARR && tools->as.array.len > 0) {
        PxValue *wire_tools = px_arr(arena);
        for (size_t index = 0; index < tools->as.array.len; index++) {
            PxValue *tool = tools->as.array.items[index];
            PxValue *parameters = px_obj_get(tool, "parameters");
            PxValue *item = px_obj(arena);
            px_obj_set(arena, item, "name", px_str(arena,
                str_or_empty(px_get_str(tool, "name"))));
            px_obj_set(arena, item, "description", px_str(arena,
                str_or_empty(px_get_str(tool, "description"))));
            px_obj_set(arena, item, "input_schema",
                parameters == NULL ? px_obj(arena) : parameters);
            px_arr_push(arena, wire_tools, item);
        }
        px_obj_set(arena, out, "tools", wire_tools);
    }
    return out;
}

static PxValue *parse_content(PxArena *arena, PxValue *blocks,
        const char **error) {
    size_t text_length = 0;
    for (size_t index = 0; index < blocks->as.array.len; index++) {
        PxValue *block = blocks->as.array.items[index];
        const char *type = px_get_str(block, "type");
        if (type != NULL && strcmp(type, "text") == 0) {
            const char *text = px_get_str(block, "text");
            if (text != NULL) text_length += strlen(text);
        }
    }
    char *text = px_arena_alloc(arena, text_length + 1);
    PxValue *calls = px_arr(arena);
    if (text == NULL) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    text[0] = '\0';
    for (size_t index = 0; index < blocks->as.array.len; index++) {
        PxValue *block = blocks->as.array.items[index];
        const char *type = px_get_str(block, "type");
        if (type != NULL && strcmp(type, "text") == 0) {
            const char *value = px_get_str(block, "text");
            if (value != NULL) strcat(text, value);
        } else if (type != NULL && strcmp(type, "tool_use") == 0) {
            PxValue *input = px_obj_get(block, "input");
            PxValue *call = px_obj(arena);
            px_obj_set(arena, call, "id", px_str(arena,
                str_or_empty(px_get_str(block, "id"))));
            px_obj_set(arena, call, "name", px_str(arena,
                str_or_empty(px_get_str(block, "name"))));
            px_obj_set(arena, call, "arguments",
                input == NULL ? px_obj(arena) : input);
            px_arr_push(arena, calls, call);
        }
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content", px_str(arena, text));
    px_obj_set(arena, out, "toolCalls", calls);
    return out;
}

PxValue *px_anthropic_parse_response(PxArena *arena, const char *text,
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
    PxValue *blocks = px_obj_get(data, "content");
    if (blocks == NULL || blocks->type != PX_ARR) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    PxValue *parsed = parse_content(arena, blocks, error);
    if (parsed == NULL) return NULL;
    PxValue *usage = px_obj_get(data, "usage");
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content", px_obj_get(parsed, "content"));
    px_obj_set(arena, out, "toolCalls", px_obj_get(parsed, "toolCalls"));
    px_obj_set(arena, out, "inputTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "input_tokens", 0)));
    px_obj_set(arena, out, "outputTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "output_tokens", 0)));
    px_obj_set(arena, out, "cachedTokens", px_num(arena,
        usage == NULL ? 0 : px_get_num(usage, "cache_read_input_tokens", 0)));
    const char *finish = px_get_str(data, "stop_reason");
    if (finish != NULL) px_obj_set(arena, out, "finishReason", px_str(arena, finish));
    return out;
}

const char *px_anthropic_url(PxArena *arena, const PxAnthropic *adapter) {
    const char *base = adapter->base_url == NULL ? "https://api.anthropic.com"
        : adapter->base_url;
    size_t length = strlen(base);
    while (length > 0 && base[length - 1] == '/') length--;
    char *url = px_arena_alloc(arena, length + 13);
    if (url == NULL) return NULL;
    memcpy(url, base, length);
    memcpy(url + length, "/v1/messages", 13);
    return url;
}

PxValue *px_anthropic_generate(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    PxAnthropic *adapter = ctx;
    const char *error = NULL;
    if (adapter == NULL || adapter->transport == NULL) return NULL;
    PxValue *payload = px_anthropic_request(arena, adapter, messages, tools, &error);
    if (payload == NULL) return NULL;
    char *body = px_stringify(arena, payload);
    if (body == NULL) return NULL;
    const char *url = px_anthropic_url(arena, adapter);
    if (url == NULL) return NULL;
    const char *response = adapter->transport(url, body, adapter->api_key,
        adapter->transport_ctx, &error);
    if (response == NULL) return NULL;
    return px_anthropic_parse_response(arena, response, &error);
}
