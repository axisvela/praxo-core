#include "openai.h"

#include <stdlib.h>
#include <string.h>

static PxValue *join_blocks(PxArena *arena, PxValue *blocks) {
    if (blocks == NULL || blocks->type != PX_ARR) {
        return px_str(arena, "");
    }
    size_t total = 0;
    for (size_t index = 0; index < blocks->as.array.len; index++) {
        PxValue *block = blocks->as.array.items[index];
        if (block == NULL || block->type != PX_OBJ) {
            continue;
        }
        const char *type = px_get_str(block, "type");
        const char *text = px_get_str(block, "text");
        if (type != NULL && strcmp(type, "text") == 0 && text != NULL) {
            total += strlen(text);
        }
    }
    char *joined = px_arena_alloc(arena, total + 1);
    if (joined == NULL) {
        return px_str(arena, "");
    }
    size_t used = 0;
    for (size_t index = 0; index < blocks->as.array.len; index++) {
        PxValue *block = blocks->as.array.items[index];
        if (block == NULL || block->type != PX_OBJ) {
            continue;
        }
        const char *type = px_get_str(block, "type");
        const char *text = px_get_str(block, "text");
        if (type != NULL && strcmp(type, "text") == 0 && text != NULL) {
            size_t length = strlen(text);
            memcpy(joined + used, text, length);
            used += length;
        }
    }
    joined[used] = '\0';
    return px_str(arena, joined);
}

PxValue *px_openai_request(PxArena *arena, const PxOpenAICompatible *adapter,
        PxValue *messages, PxValue *tools, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (adapter == NULL) {
        if (error != NULL) {
            *error = "PROVIDER_HTTP";
        }
        return NULL;
    }
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "model", px_str(arena,
        adapter->model == NULL ? "" : adapter->model));
    PxValue *wire_messages = px_arr(arena);
    if (messages != NULL && messages->type == PX_ARR) {
        for (size_t index = 0; index < messages->as.array.len; index++) {
            PxValue *message = messages->as.array.items[index];
            if (message == NULL || message->type != PX_OBJ) {
                if (error != NULL) {
                    *error = "PROVIDER_JSON";
                }
                return NULL;
            }
            const char *role = px_get_str(message, "role");
            PxValue *item = px_obj(arena);
            px_obj_set(arena, item, "role", px_str(arena, role == NULL ? "" : role));
            const char *content = px_get_str(message, "content");
            if (content == NULL || content[0] == '\0') {
                px_obj_set(arena, item, "content",
                    join_blocks(arena, px_obj_get(message, "contentBlocks")));
            } else {
                px_obj_set(arena, item, "content", px_str(arena, content));
            }
            PxValue *calls = px_obj_get(message, "toolCalls");
            if (role != NULL && strcmp(role, "assistant") == 0
                    && calls != NULL && calls->type == PX_ARR
                    && calls->as.array.len > 0) {
                PxValue *wire_calls = px_arr(arena);
                for (size_t call_index = 0; call_index < calls->as.array.len;
                        call_index++) {
                    PxValue *call = calls->as.array.items[call_index];
                    if (call == NULL || call->type != PX_OBJ) {
                        if (error != NULL) {
                            *error = "PROVIDER_JSON";
                        }
                        return NULL;
                    }
                    const char *id = px_get_str(call, "id");
                    const char *name = px_get_str(call, "name");
                    PxValue *arguments = px_obj_get(call, "arguments");
                    PxValue *entry = px_obj(arena);
                    PxValue *function = px_obj(arena);
                    px_obj_set(arena, entry, "id", px_str(arena, id == NULL ? "" : id));
                    px_obj_set(arena, entry, "type", px_str(arena, "function"));
                    px_obj_set(arena, function, "name",
                        px_str(arena, name == NULL ? "" : name));
                    if (arguments == NULL) {
                        px_obj_set(arena, function, "arguments",
                            px_str(arena, "{}"));
                    } else if (arguments->type == PX_STR) {
                        px_obj_set(arena, function, "arguments",
                            px_str(arena, arguments->as.string));
                    } else {
                        char *encoded = px_stringify(arena, arguments);
                        px_obj_set(arena, function, "arguments",
                            px_str(arena, encoded == NULL ? "{}" : encoded));
                    }
                    px_obj_set(arena, entry, "function", function);
                    px_arr_push(arena, wire_calls, entry);
                }
                px_obj_set(arena, item, "tool_calls", wire_calls);
            }
            if (role != NULL && strcmp(role, "tool") == 0) {
                const char *tool_id = px_get_str(message, "toolId");
                if (tool_id != NULL && tool_id[0] != '\0') {
                    px_obj_set(arena, item, "tool_call_id", px_str(arena, tool_id));
                }
            }
            px_arr_push(arena, wire_messages, item);
        }
    }
    px_obj_set(arena, out, "messages", wire_messages);
    if (tools != NULL && tools->type == PX_ARR && tools->as.array.len > 0) {
        PxValue *wire_tools = px_arr(arena);
        for (size_t index = 0; index < tools->as.array.len; index++) {
            PxValue *tool = tools->as.array.items[index];
            if (tool == NULL || tool->type != PX_OBJ) {
                if (error != NULL) {
                    *error = "PROVIDER_JSON";
                }
                return NULL;
            }
            const char *name = px_get_str(tool, "name");
            const char *description = px_get_str(tool, "description");
            PxValue *parameters = px_obj_get(tool, "parameters");
            if (parameters == NULL || parameters->type == PX_NULL) {
                parameters = px_parse(arena, "{\"type\":\"object\"}");
            }
            PxValue *entry = px_obj(arena);
            PxValue *function = px_obj(arena);
            px_obj_set(arena, entry, "type", px_str(arena, "function"));
            px_obj_set(arena, function, "name",
                px_str(arena, name == NULL ? "" : name));
            px_obj_set(arena, function, "description",
                px_str(arena, description == NULL ? "" : description));
            px_obj_set(arena, function, "parameters", parameters);
            px_obj_set(arena, entry, "function", function);
            px_arr_push(arena, wire_tools, entry);
        }
        px_obj_set(arena, out, "tools", wire_tools);
    }
    return out;
}

PxValue *px_openai_parse_response(PxArena *arena, const char *text,
        const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    PxValue *data = px_parse(arena, text == NULL ? "" : text);
    if (data == NULL || data->type != PX_OBJ) {
        if (error != NULL) {
            *error = "PROVIDER_JSON";
        }
        return NULL;
    }
    PxValue *choices = px_obj_get(data, "choices");
    PxValue *choice = choices != NULL && choices->type == PX_ARR
        && choices->as.array.len > 0 ? choices->as.array.items[0] : NULL;
    PxValue *message = choice == NULL ? NULL : px_obj_get(choice, "message");
    PxValue *out = px_obj(arena);
    const char *content = message != NULL && message->type == PX_OBJ
        ? px_get_str(message, "content") : NULL;
    px_obj_set(arena, out, "content",
        px_str(arena, content == NULL ? "" : content));
    PxValue *calls = message == NULL ? NULL : px_obj_get(message, "tool_calls");
    if (calls != NULL && calls->type == PX_ARR) {
        PxValue *wire_calls = px_arr(arena);
        for (size_t index = 0; index < calls->as.array.len; index++) {
            PxValue *call = calls->as.array.items[index];
            if (call == NULL || call->type != PX_OBJ) {
                if (error != NULL) {
                    *error = "PROVIDER_JSON";
                }
                return NULL;
            }
            const char *id = px_get_str(call, "id");
            PxValue *function = px_obj_get(call, "function");
            const char *name = function == NULL ? NULL : px_get_str(function, "name");
            PxValue *raw = function == NULL ? NULL : px_obj_get(function, "arguments");
            PxValue *arguments = px_obj(arena);
            if (raw != NULL && raw->type == PX_STR && raw->as.string[0] != '\0') {
                arguments = px_parse(arena, raw->as.string);
                if (arguments == NULL || arguments->type != PX_OBJ) {
                    if (error != NULL) {
                        *error = "PROVIDER_JSON";
                    }
                    return NULL;
                }
            }
            PxValue *entry = px_obj(arena);
            px_obj_set(arena, entry, "id", px_str(arena, id == NULL ? "" : id));
            px_obj_set(arena, entry, "name",
                px_str(arena, name == NULL ? "" : name));
            px_obj_set(arena, entry, "arguments", arguments);
            px_arr_push(arena, wire_calls, entry);
        }
        px_obj_set(arena, out, "toolCalls", wire_calls);
    }
    PxValue *usage = px_obj_get(data, "usage");
    double input = usage != NULL && usage->type == PX_OBJ
        ? px_get_num(usage, "prompt_tokens", 0) : 0;
    double output = usage != NULL && usage->type == PX_OBJ
        ? px_get_num(usage, "completion_tokens", 0) : 0;
    px_obj_set(arena, out, "inputTokens", px_num(arena, input));
    px_obj_set(arena, out, "outputTokens", px_num(arena, output));
    const char *finish = choice == NULL ? NULL
        : px_get_str(choice, "finish_reason");
    if (finish != NULL) {
        px_obj_set(arena, out, "finishReason", px_str(arena, finish));
    }
    return out;
}

const char *px_openai_url(PxArena *arena, const PxOpenAICompatible *adapter) {
    if (adapter == NULL || adapter->base_url == NULL) {
        return "";
    }
    size_t length = strlen(adapter->base_url);
    while (length > 0 && adapter->base_url[length - 1] == '/') {
        length--;
    }
    const char *suffix = "/chat/completions";
    size_t suffix_length = strlen(suffix);
    if (length >= suffix_length
            && strncmp(adapter->base_url + length - suffix_length,
                suffix, suffix_length) == 0) {
        char *out = px_arena_alloc(arena, length + 1);
        if (out == NULL) {
            return "";
        }
        memcpy(out, adapter->base_url, length);
        out[length] = '\0';
        return out;
    }
    char *out = px_arena_alloc(arena, length + suffix_length + 1);
    if (out == NULL) {
        return "";
    }
    memcpy(out, adapter->base_url, length);
    memcpy(out + length, suffix, suffix_length + 1);
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
} PxOpenAIStreamCall;

static int append_stream_text(char **buffer, size_t *length, size_t *capacity,
        const char *text) {
    if (text == NULL) {
        return 1;
    }
    size_t extra = strlen(text);
    if (*length + extra + 1 > *capacity) {
        size_t next = *capacity == 0 ? 64 : *capacity;
        while (next < *length + extra + 1) {
            next *= 2;
        }
        char *grown = realloc(*buffer, next);
        if (grown == NULL) {
            return 0;
        }
        *buffer = grown;
        *capacity = next;
    }
    memcpy(*buffer + *length, text, extra);
    *length += extra;
    (*buffer)[*length] = '\0';
    return 1;
}

static void free_stream_calls(PxOpenAIStreamCall *calls, size_t count) {
    for (size_t index = 0; index < count; index++) {
        free(calls[index].id);
        free(calls[index].name);
        free(calls[index].arguments);
    }
}

PxValue *px_openai_generate_stream(PxArena *arena, PxValue *messages,
        PxValue *tools, const char *(*on_delta)(const char *delta, void *ctx),
        void *ctx, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    PxOpenAICompatible *adapter = ctx;
    if (adapter == NULL || adapter->base_url == NULL
            || adapter->base_url[0] == '\0' || adapter->transport == NULL) {
        if (error != NULL) {
            *error = "PROVIDER_HTTP";
        }
        return NULL;
    }
    const char *request_error = NULL;
    PxValue *request = px_openai_request(arena, adapter, messages, tools,
        &request_error);
    if (request == NULL || request_error != NULL) {
        if (error != NULL) {
            *error = request_error == NULL ? "PROVIDER_JSON" : request_error;
        }
        return NULL;
    }
    px_obj_set(arena, request, "stream", px_bool(arena, true));
    char *payload = px_stringify(arena, request);
    if (payload == NULL) {
        if (error != NULL) {
            *error = "PROVIDER_JSON";
        }
        return NULL;
    }
    const char *url = px_openai_url(arena, adapter);
    const char *body = adapter->transport(url, payload, adapter->api_key,
        adapter->transport_ctx, &request_error);
    if (request_error != NULL || body == NULL) {
        if (error != NULL) {
            *error = request_error == NULL ? "PROVIDER_HTTP" : request_error;
        }
        return NULL;
    }

    char *copy = px_arena_strdup(arena, body);
    char *content = NULL;
    size_t content_length = 0;
    size_t content_capacity = 0;
    PxOpenAIStreamCall calls[64];
    memset(calls, 0, sizeof(calls));
    size_t call_count = 0;
    const char *finish_reason = NULL;
    double input_tokens = 0;
    double output_tokens = 0;
    const char *stream_error = NULL;
    int done = 0;

    for (char *line = strtok(copy, "\n"); line != NULL;
            line = strtok(NULL, "\n")) {
        size_t length = strlen(line);
        if (length > 0 && line[length - 1] == '\r') {
            line[length - 1] = '\0';
        }
        if (strncmp(line, "data:", 5) != 0) {
            continue;
        }
        char *data = line + 5;
        while (*data == ' ') {
            data++;
        }
        if (strcmp(data, "[DONE]") == 0) {
            done = 1;
            break;
        }
        if (data[0] == '\0') {
            continue;
        }
        PxValue *chunk = px_parse(arena, data);
        if (chunk == NULL || chunk->type != PX_OBJ) {
            stream_error = "MODEL_STREAM";
            break;
        }
        PxValue *usage = px_obj_get(chunk, "usage");
        if (usage != NULL && usage->type == PX_OBJ) {
            input_tokens = px_get_num(usage, "prompt_tokens", input_tokens);
            output_tokens = px_get_num(usage, "completion_tokens", output_tokens);
        }
        PxValue *choices = px_obj_get(chunk, "choices");
        if (choices == NULL || choices->type != PX_ARR) {
            continue;
        }
        for (size_t choice_index = 0; choice_index < choices->as.array.len;
                choice_index++) {
            PxValue *choice = choices->as.array.items[choice_index];
            if (choice == NULL || choice->type != PX_OBJ) {
                continue;
            }
            const char *reason = px_get_str(choice, "finish_reason");
            if (reason != NULL) {
                finish_reason = reason;
            }
            PxValue *delta = px_obj_get(choice, "delta");
            if (delta == NULL || delta->type != PX_OBJ) {
                continue;
            }
            const char *text = px_get_str(delta, "content");
            if (text != NULL && text[0] != '\0') {
                if (!append_stream_text(&content, &content_length,
                        &content_capacity, text)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                if (on_delta != NULL) {
                    const char *callback_error = on_delta(text, ctx);
                    if (callback_error != NULL) {
                        stream_error = callback_error;
                        break;
                    }
                }
            }
            PxValue *tool_calls = px_obj_get(delta, "tool_calls");
            if (tool_calls == NULL || tool_calls->type != PX_ARR) {
                continue;
            }
            for (size_t tool_index = 0; tool_index < tool_calls->as.array.len;
                    tool_index++) {
                PxValue *item = tool_calls->as.array.items[tool_index];
                if (item == NULL || item->type != PX_OBJ) {
                    continue;
                }
                double raw_index = px_get_num(item, "index", (double)call_count);
                if (raw_index < 0 || raw_index >= 64) {
                    stream_error = "PROVIDER_JSON";
                    break;
                }
                size_t index = (size_t)raw_index;
                if (index + 1 > call_count) {
                    call_count = index + 1;
                }
                PxOpenAIStreamCall *call = &calls[index];
                const char *id = px_get_str(item, "id");
                if (id != NULL && id[0] != '\0'
                        && !append_stream_text(&call->id, &call->id_length,
                            &call->id_capacity, id)) {
                    stream_error = "MODEL_STREAM";
                    break;
                }
                PxValue *function_value = px_obj_get(item, "function");
                if (function_value != NULL && function_value->type == PX_OBJ) {
                    const char *name = px_get_str(function_value, "name");
                    if (name != NULL && name[0] != '\0'
                            && !append_stream_text(&call->name, &call->name_length,
                                &call->name_capacity, name)) {
                        stream_error = "MODEL_STREAM";
                        break;
                    }
                    const char *arguments = px_get_str(function_value, "arguments");
                    if (arguments != NULL && arguments[0] != '\0'
                            && !append_stream_text(&call->arguments,
                                &call->arguments_length,
                                &call->arguments_capacity, arguments)) {
                        stream_error = "MODEL_STREAM";
                        break;
                    }
                }
            }
            if (stream_error != NULL) {
                break;
            }
        }
        if (stream_error != NULL) {
            break;
        }
    }
    if (stream_error == NULL && !done && finish_reason == NULL) {
        stream_error = "MODEL_STREAM";
    }
    if (stream_error != NULL) {
        free_stream_calls(calls, call_count);
        free(content);
        if (error != NULL) {
            *error = stream_error;
        }
        return NULL;
    }

    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "content", px_str(arena,
        content == NULL ? "" : content));
    if (call_count > 0) {
        PxValue *wire_calls = px_arr(arena);
        for (size_t index = 0; index < call_count; index++) {
            if (calls[index].name == NULL) {
                continue;
            }
            PxValue *arguments = px_obj(arena);
            if (calls[index].arguments != NULL
                    && calls[index].arguments[0] != '\0') {
                arguments = px_parse(arena, calls[index].arguments);
                if (arguments == NULL || arguments->type != PX_OBJ) {
                    free_stream_calls(calls, call_count);
                    free(content);
                    if (error != NULL) {
                        *error = "PROVIDER_JSON";
                    }
                    return NULL;
                }
            }
            PxValue *entry = px_obj(arena);
            px_obj_set(arena, entry, "id", px_str(arena,
                calls[index].id == NULL ? "" : calls[index].id));
            px_obj_set(arena, entry, "name", px_str(arena, calls[index].name));
            px_obj_set(arena, entry, "arguments", arguments);
            px_arr_push(arena, wire_calls, entry);
        }
        px_obj_set(arena, out, "toolCalls", wire_calls);
    }
    px_obj_set(arena, out, "inputTokens", px_num(arena, input_tokens));
    px_obj_set(arena, out, "outputTokens", px_num(arena, output_tokens));
    if (finish_reason != NULL) {
        px_obj_set(arena, out, "finishReason",
            px_str(arena, finish_reason));
    }
    free_stream_calls(calls, call_count);
    free(content);
    return out;
}

PxValue *px_openai_generate(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    PxOpenAICompatible *adapter = ctx;
    if (adapter == NULL || adapter->base_url == NULL
            || adapter->base_url[0] == '\0' || adapter->transport == NULL) {
        return NULL;
    }
    const char *error = NULL;
    PxValue *request = px_openai_request(arena, adapter, messages, tools, &error);
    if (request == NULL || error != NULL) {
        return NULL;
    }
    char *payload = px_stringify(arena, request);
    if (payload == NULL) {
        return NULL;
    }
    const char *url = px_openai_url(arena, adapter);
    const char *body = adapter->transport(url, payload, adapter->api_key,
        adapter->transport_ctx, &error);
    if (error != NULL || body == NULL) {
        return NULL;
    }
    return px_openai_parse_response(arena, body, &error);
}
