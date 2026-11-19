#include "anthropic.h"

#include <stdlib.h>
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
} PxAnthropicStreamCall;

static int append_stream_text(char **buffer, size_t *length, size_t *capacity,
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

static void free_stream_calls(PxAnthropicStreamCall *calls, size_t count) {
    for (size_t index = 0; index < count; index++) {
        free(calls[index].id);
        free(calls[index].name);
        free(calls[index].arguments);
    }
}

static PxValue *parse_stream_response(PxArena *arena, const char *text,
        const char *(*on_delta)(const char *delta, void *ctx), void *ctx,
        const char **error) {
    char *copy = px_arena_strdup(arena, text == NULL ? "" : text);
    char *content = NULL;
    size_t content_length = 0;
    size_t content_capacity = 0;
    PxAnthropicStreamCall calls[8];
    memset(calls, 0, sizeof(calls));
    size_t call_count = 0;
    const char *stop_reason = NULL;
    double input_tokens = 0;
    double output_tokens = 0;
    double cached_tokens = 0;
    const char *stream_error = NULL;
    int stopped = 0;
    for (char *line = strtok(copy, "\n"); line != NULL;
            line = strtok(NULL, "\n")) {
        size_t length = strlen(line);
        if (length > 0 && line[length - 1] == '\r') line[length - 1] = '\0';
        if (strncmp(line, "data:", 5) != 0) continue;
        char *data = line + 5;
        while (*data == ' ') data++;
        if (data[0] == '\0') continue;
        PxValue *event = px_parse(arena, data);
        if (event == NULL || event->type != PX_OBJ) {
            stream_error = "MODEL_STREAM";
            break;
        }
        const char *kind = px_get_str(event, "type");
        if (kind == NULL) continue;
        if (strcmp(kind, "message_start") == 0) {
            PxValue *message = px_obj_get(event, "message");
            PxValue *usage = message == NULL ? NULL : px_obj_get(message, "usage");
            if (usage != NULL) {
                input_tokens = px_get_num(usage, "input_tokens", input_tokens);
                cached_tokens = px_get_num(usage, "cache_read_input_tokens",
                    cached_tokens);
            }
        } else if (strcmp(kind, "content_block_start") == 0) {
            double index_value = px_get_num(event, "index", (double)call_count);
            if (index_value < 0 || index_value >= 8) {
                stream_error = "PROVIDER_JSON";
                break;
            }
            size_t index = (size_t)index_value;
            if (index + 1 > call_count) call_count = index + 1;
            PxValue *block = px_obj_get(event, "content_block");
            const char *block_type = block == NULL ? NULL
                : px_get_str(block, "type");
            if (block_type != NULL && strcmp(block_type, "tool_use") == 0) {
                PxAnthropicStreamCall *call = &calls[index];
                const char *id = px_get_str(block, "id");
                const char *name = px_get_str(block, "name");
                if (!append_stream_text(&call->id, &call->id_length,
                        &call->id_capacity, id)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                if (!append_stream_text(&call->name, &call->name_length,
                        &call->name_capacity, name)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
            }
        } else if (strcmp(kind, "content_block_delta") == 0) {
            double index_value = px_get_num(event, "index", 0);
            PxValue *delta = px_obj_get(event, "delta");
            const char *delta_type = delta == NULL ? NULL
                : px_get_str(delta, "type");
            if (delta_type == NULL) continue;
            if (strcmp(delta_type, "text_delta") == 0) {
                const char *piece = px_get_str(delta, "text");
                if (piece != NULL && piece[0] != '\0') {
                    if (!append_stream_text(&content, &content_length,
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
            } else if (strcmp(delta_type, "input_json_delta") == 0
                    && index_value >= 0 && index_value < 8) {
                size_t index = (size_t)index_value;
                if (index < call_count) {
                    const char *partial = px_get_str(delta, "partial_json");
                    if (!append_stream_text(&calls[index].arguments,
                            &calls[index].arguments_length,
                            &calls[index].arguments_capacity, partial)) {
                        stream_error = "MODEL_STREAM";
                        break;
                    }
                }
            }
        } else if (strcmp(kind, "message_delta") == 0) {
            PxValue *delta = px_obj_get(event, "delta");
            const char *reason = delta == NULL ? NULL
                : px_get_str(delta, "stop_reason");
            if (reason != NULL) stop_reason = reason;
            PxValue *usage = px_obj_get(event, "usage");
            if (usage != NULL) {
                output_tokens = px_get_num(usage, "output_tokens",
                    output_tokens);
            }
        } else if (strcmp(kind, "message_stop") == 0) {
            stopped = 1;
        } else if (strcmp(kind, "error") == 0) {
            stream_error = "MODEL_STREAM";
            break;
        }
    }
    if (stream_error == NULL && !stopped && stop_reason == NULL) {
        stream_error = "MODEL_STREAM";
    }
    if (stream_error != NULL) {
        free_stream_calls(calls, call_count);
        free(content);
        if (error != NULL) *error = stream_error;
        return NULL;
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content", px_str(arena,
        content == NULL ? "" : content));
    PxValue *tool_calls = px_arr(arena);
    for (size_t index = 0; index < call_count; index++) {
        if (calls[index].name == NULL || calls[index].name[0] == '\0') continue;
        PxValue *arguments = px_obj(arena);
        if (calls[index].arguments != NULL
                && calls[index].arguments[0] != '\0') {
            arguments = px_parse(arena, calls[index].arguments);
            if (arguments == NULL || arguments->type != PX_OBJ) {
                free_stream_calls(calls, call_count);
                free(content);
                if (error != NULL) *error = "PROVIDER_JSON";
                return NULL;
            }
        }
        PxValue *call = px_obj(arena);
        px_obj_set(arena, call, "id", px_str(arena,
            calls[index].id == NULL ? "" : calls[index].id));
        px_obj_set(arena, call, "name", px_str(arena, calls[index].name));
        px_obj_set(arena, call, "arguments", arguments);
        px_arr_push(arena, tool_calls, call);
    }
    px_obj_set(arena, out, "toolCalls", tool_calls);
    px_obj_set(arena, out, "inputTokens", px_num(arena, input_tokens));
    px_obj_set(arena, out, "outputTokens", px_num(arena, output_tokens));
    px_obj_set(arena, out, "cachedTokens", px_num(arena, cached_tokens));
    if (stop_reason != NULL) {
        px_obj_set(arena, out, "finishReason", px_str(arena, stop_reason));
    }
    free_stream_calls(calls, call_count);
    free(content);
    return out;
}

PxValue *px_anthropic_generate_stream(PxArena *arena, PxValue *messages,
        PxValue *tools, const char *(*on_delta)(const char *delta, void *ctx),
        void *ctx, const char **error) {
    if (error != NULL) *error = NULL;
    PxAnthropic *adapter = ctx;
    if (adapter == NULL || adapter->transport == NULL) {
        if (error != NULL) *error = "PROVIDER_HTTP";
        return NULL;
    }
    const char *request_error = NULL;
    PxValue *payload = px_anthropic_request(arena, adapter, messages, tools,
        &request_error);
    if (payload == NULL || request_error != NULL) {
        if (error != NULL) *error = request_error == NULL
            ? "PROVIDER_JSON" : request_error;
        return NULL;
    }
    px_obj_set(arena, payload, "stream", px_bool(arena, true));
    char *body = px_stringify(arena, payload);
    if (body == NULL) {
        if (error != NULL) *error = "PROVIDER_JSON";
        return NULL;
    }
    const char *url = px_anthropic_url(arena, adapter);
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
    return parse_stream_response(arena, response, on_delta, ctx, error);
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
