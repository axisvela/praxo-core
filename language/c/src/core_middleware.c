#include "praxo_core.h"
#include "jsonschema.h"

#include <ctype.h>
#include <string.h>

static bool pii_char(char ch) {
    return isalnum((unsigned char)ch) || strchr("._%+-", ch) != NULL;
}

char *px_pii_redact(PxArena *arena, const char *text) {
    size_t size = strlen(text);
    char *output = px_arena_alloc(arena, size * 2 + 64);
    size_t written = 0;
    size_t cursor = 0;
    while (cursor < size) {
        size_t at = cursor;
        while (at < size && text[at] != '@') {
            at++;
        }
        if (at >= size) {
            memcpy(output + written, text + cursor, size - cursor);
            written += size - cursor;
            break;
        }
        size_t first = at;
        while (first > cursor && pii_char(text[first - 1])) {
            first--;
        }
        size_t last = at + 1;
        while (last < size && (isalnum((unsigned char)text[last]) || text[last] == '.' || text[last] == '-')) {
            last++;
        }
        size_t last_dot = 0;
        for (size_t index = at + 1; index < last; index++) {
            if (text[index] == '.') {
                last_dot = index;
            }
        }
        size_t suffix = last_dot + 1;
        while (suffix < last && isalpha((unsigned char)text[suffix])) {
            suffix++;
        }
        if (first < at && last_dot > at + 1 && suffix - last_dot - 1 >= 2) {
            memcpy(output + written, text + cursor, first - cursor);
            written += first - cursor;
            memcpy(output + written, "[REDACTED:email]", 16);
            written += 16;
            cursor = suffix;
        } else {
            output[written++] = text[cursor++];
        }
    }
    output[written] = '\0';
    return output;
}

PxValue *px_redact_value(PxArena *arena, PxValue *value) {
    if (value == NULL) {
        return NULL;
    }
    switch (value->type) {
    case PX_STR:
        return px_str(arena, px_pii_redact(arena, value->as.string));
    case PX_ARR: {
        PxValue *array = px_arr(arena);
        for (size_t index = 0; index < value->as.array.len; index++) {
            px_arr_push(arena, array, px_redact_value(arena, value->as.array.items[index]));
        }
        return array;
    }
    case PX_OBJ: {
        PxValue *object = px_obj(arena);
        for (size_t index = 0; index < value->as.object.len; index++) {
            PxPair *pair = &value->as.object.pairs[index];
            px_obj_set(arena, object, pair->key, px_redact_value(arena, pair->value));
        }
        return object;
    }
    default:
        return value;
    }
}

PxValue *px_extract_json(PxArena *arena, const char *text) {
    const char *start = NULL;
    for (const char *cursor = text; *cursor != '\0'; cursor++) {
        if (*cursor == '{' || *cursor == '[') {
            start = cursor;
            break;
        }
    }
    return start == NULL ? NULL : px_parse(arena, start);
}

static bool valid_structured(PxArena *arena, PxValue *schema, const char *text) {
    PxValue *value = px_extract_json(arena, text);
    if (value == NULL) {
        return false;
    }
    PxValue *errors = px_arr(arena);
    px_schema_validate(arena, schema, value, "$", errors);
    return errors->as.array.len == 0;
}

static char *structured_attempt(PxArena *arena, const PxStructuredOutput *config,
        const char *text, int attempt) {
    if (valid_structured(arena, config->schema, text)) {
        return (char *)text;
    }
    if (attempt >= config->max_repairs || config->repairer == NULL) {
        return NULL;
    }
    char *repaired = config->repairer(arena, text, config->ctx);
    if (repaired == NULL || repaired[0] == '\0') {
        return NULL;
    }
    return structured_attempt(arena, config, repaired, attempt + 1);
}

char *px_apply_structured(PxArena *arena, const PxStructuredOutput *config,
        const char *text) {
    return structured_attempt(arena, config, text, 0);
}

void px_call_limit_init(PxCallLimit *limit, int model_limit, int tool_limit) {
    limit->model_limit = model_limit;
    limit->tool_limit = tool_limit;
    limit->models = 0;
    limit->tools = 0;
}

const char *px_call_limit_model(PxCallLimit *limit) {
    limit->models++;
    return limit->model_limit > 0 && limit->models > limit->model_limit
        ? "AGENT_MODEL_CALL_LIMIT" : NULL;
}

const char *px_call_limit_tool(PxCallLimit *limit) {
    limit->tools++;
    return limit->tool_limit > 0 && limit->tools > limit->tool_limit
        ? "AGENT_TOOL_CALL_LIMIT" : NULL;
}

static const char *STREAM_KINDS[] = {
    "values", "updates", "messages", "tasks", "debug", "checkpoint"
};

size_t px_stream_kinds(const char ***out) {
    *out = STREAM_KINDS;
    return sizeof(STREAM_KINDS) / sizeof(STREAM_KINDS[0]);
}

const char *px_fallback(const char *primary, const char *fallback,
        bool primary_failed) {
    return primary_failed ? fallback : primary;
}

size_t px_select_tools(PxArena *arena, const char **selection,
        size_t selection_count, const char **tools, size_t tool_count,
        const char ***out) {
    const char **selected = px_arena_alloc(arena, sizeof(char *) * (tool_count + 1));
    size_t count = 0;
    for (size_t index = 0; index < tool_count; index++) {
        if (px_check_tool_selected(selection, selection_count, tools[index]) == NULL) {
            selected[count++] = tools[index];
        }
    }
    *out = selected;
    return count;
}

const char *px_check_tool_selected(const char **selection,
        size_t selection_count, const char *name) {
    for (size_t index = 0; index < selection_count; index++) {
        if (selection[index] != NULL && name != NULL && strcmp(selection[index], name) == 0) {
            return NULL;
        }
    }
    return "AGENT_TOOL_NOT_SELECTED";
}
