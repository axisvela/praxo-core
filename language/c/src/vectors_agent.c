#include "vectors_agent.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "jsonschema.h"

static bool check(bool condition, const char *detail) {
    if (!condition) {
        fprintf(stderr, "  %s\n", detail);
    }
    return condition;
}

static bool local_char(char ch) {
    return isalnum((unsigned char)ch) || ch == '.' || ch == '_'
        || ch == '%' || ch == '+' || ch == '-';
}

static bool domain_char(char ch) {
    return isalnum((unsigned char)ch) || ch == '.' || ch == '-';
}

static char *redact_email(PxArena *arena, const char *text) {
    size_t size = strlen(text);
    char *out = px_arena_alloc(arena, size * 2 + 64);
    size_t written = 0;
    const char *cursor = text;
    while (*cursor != '\0') {
        const char *at = strchr(cursor, '@');
        if (at == NULL) {
            size_t remaining = strlen(cursor);
            memcpy(out + written, cursor, remaining);
            written += remaining;
            break;
        }
        const char *start = at;
        while (start > cursor && local_char(start[-1])) {
            start--;
        }
        const char *end = at + 1;
        while (*end != '\0' && domain_char(*end)) {
            end++;
        }
        bool valid = start < at;
        const char *dot = start < at ? strchr(at + 1, '.') : NULL;
        if (dot != NULL && dot < end) {
            const char *after = dot + 1;
            bool letters = false;
            while (after < end) {
                if (isalpha((unsigned char)*after)) {
                    letters = true;
                }
                after++;
            }
            valid = valid && letters;
        } else {
            valid = false;
        }
        if (!valid) {
            out[written++] = *cursor++;
            continue;
        }
        size_t prefix = (size_t)(start - cursor);
        memcpy(out + written, cursor, prefix);
        written += prefix;
        const char *replacement = "[REDACTED:email]";
        size_t replacement_len = strlen(replacement);
        memcpy(out + written, replacement, replacement_len);
        written += replacement_len;
        cursor = end;
    }
    out[written] = '\0';
    return out;
}

static PxValue *redact_value(PxArena *arena, PxValue *value) {
    if (value == NULL) {
        return NULL;
    }
    if (value->type == PX_STR) {
        return px_str(arena, redact_email(arena, value->as.string));
    }
    if (value->type == PX_ARR) {
        PxValue *out = px_arr(arena);
        for (size_t index = 0; index < value->as.array.len; index++) {
            px_arr_push(arena, out, redact_value(arena, value->as.array.items[index]));
        }
        return out;
    }
    if (value->type == PX_OBJ) {
        PxValue *out = px_obj(arena);
        for (size_t index = 0; index < value->as.object.len; index++) {
            PxPair *pair = &value->as.object.pairs[index];
            px_obj_set(arena, out, pair->key, redact_value(arena, pair->value));
        }
        return out;
    }
    return value;
}

static bool schema_output_valid(
    PxArena *arena, PxValue *schema, const char *output) {
    PxValue *data = px_parse(arena, output);
    if (data == NULL) {
        return false;
    }
    PxValue *errors = px_arr(arena);
    px_schema_validate(arena, schema, data, "$", errors);
    return errors->as.array.len == 0;
}

static bool run_structured(
    PxArena *arena, PxValue *input, PxValue *expect) {
    const char *output_value = px_get_str(input, "output");
    PxValue *schema = px_obj_get(input, "schema");
    bool valid = schema_output_valid(
        arena, schema, output_value == NULL ? "" : output_value);
    if (!valid) {
        const char *repair = px_get_str(input, "repairOutput");
        if (repair != NULL) {
            output_value = repair;
            valid = schema_output_valid(arena, schema, repair);
        }
    }
    if (px_get_bool(expect, "ok", false)) {
        const char *want = px_get_str(expect, "output");
        return check(valid && want != NULL && strcmp(output_value, want) == 0,
                     "structured output mismatch");
    }
    const char *code = px_get_str(expect, "errorCode");
    return check(!valid && code != NULL && strcmp(code, "AGENT_STRUCTURED_OUTPUT") == 0,
                 "structured error mismatch");
}

static bool run_call_limit(
    PxArena *arena, PxValue *input, PxValue *expect) {
    int model_limit = (int)px_get_num(input, "modelLimit", 0);
    int tool_limit = (int)px_get_num(input, "toolLimit", 0);
    int models = 0;
    int tools = 0;
    PxValue *calls = px_obj_get(input, "calls");
    PxValue *outcomes = px_arr(arena);
    if (calls != NULL && calls->type == PX_ARR) {
        for (size_t index = 0; index < calls->as.array.len; index++) {
            const char *kind = calls->as.array.items[index]->as.string;
            const char *outcome = "ok";
            if (strcmp(kind, "model") == 0) {
                models++;
                if (model_limit > 0 && models > model_limit) {
                    outcome = "AGENT_MODEL_CALL_LIMIT";
                }
            } else if (strcmp(kind, "tool") == 0) {
                tools++;
                if (tool_limit > 0 && tools > tool_limit) {
                    outcome = "AGENT_TOOL_CALL_LIMIT";
                }
            }
            px_arr_push(arena, outcomes, px_str(arena, outcome));
        }
    }
    return check(px_equals(outcomes, px_obj_get(expect, "outcomes")),
                 "outcomes mismatch");
}

static bool string_in(PxValue *array, const char *value) {
    if (array == NULL || array->type != PX_ARR) {
        return false;
    }
    for (size_t index = 0; index < array->as.array.len; index++) {
        PxValue *item = array->as.array.items[index];
        if (item->type == PX_STR && strcmp(item->as.string, value) == 0) {
            return true;
        }
    }
    return false;
}

static bool tool_exists(PxValue *tools, const char *name) {
    if (tools == NULL || tools->type != PX_ARR) {
        return false;
    }
    for (size_t index = 0; index < tools->as.array.len; index++) {
        PxValue *item = tools->as.array.items[index];
        const char *tool_name = item->type == PX_OBJ
            ? px_get_str(item, "name") : NULL;
        if (tool_name != NULL && strcmp(tool_name, name) == 0) {
            return true;
        }
    }
    return false;
}

static bool run_tool_selection(
    PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *selected = px_obj_get(input, "selected");
    PxValue *tools = px_obj_get(input, "tools");
    PxValue *advertised = px_arr(arena);
    if (tools != NULL && tools->type == PX_ARR) {
        for (size_t index = 0; index < tools->as.array.len; index++) {
            const char *name = tools->as.array.items[index]->as.string;
            if (string_in(selected, name)) {
                px_arr_push(arena, advertised, px_str(arena, name));
            }
        }
    }
    if (!check(px_equals(advertised, px_obj_get(expect, "advertised")),
               "advertised mismatch")) {
        return false;
    }
    const char *requested = px_get_str(input, "requested");
    const char *reject = string_in(selected, requested)
        ? "ok" : "AGENT_TOOL_NOT_SELECTED";
    return check(strcmp(reject, px_get_str(expect, "reject")) == 0,
                 "reject mismatch");
}

bool px_run_middleware(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *operation = px_get_str(input, "operation");
    if (operation == NULL) {
        return false;
    }
    if (strcmp(operation, "pii") == 0) {
        const char *text = px_get_str(input, "text");
        char *got = redact_email(arena, text == NULL ? "" : text);
        return check(strcmp(got, px_get_str(expect, "text")) == 0,
                     "pii text mismatch");
    }
    if (strcmp(operation, "pii-value") == 0) {
        PxValue *got = redact_value(arena, px_obj_get(input, "value"));
        return check(px_equals(got, px_obj_get(expect, "value")),
                     "pii value mismatch");
    }
    if (strcmp(operation, "structured") == 0) {
        return run_structured(arena, input, expect);
    }
    if (strcmp(operation, "call-limit") == 0) {
        return run_call_limit(arena, input, expect);
    }
    if (strcmp(operation, "tool-selection") == 0) {
        return run_tool_selection(arena, input, expect);
    }
    if (strcmp(operation, "fallback") == 0) {
        return check(
            strcmp(px_get_str(input, "fallbackContent"),
                   px_get_str(expect, "output")) == 0,
            "fallback output mismatch");
    }
    return false;
}

static PxValue *array_of_strings(PxArena *arena) {
    return px_arr(arena);
}

static bool run_agent(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *script = px_obj_get(input, "script");
    PxValue *tools = px_obj_get(input, "tools");
    int max_steps = (int)px_get_num(input, "maxSteps", 0);
    if (max_steps <= 0) {
        max_steps = 8;
    }
    long max_tokens = (long)px_get_num(input, "maxTokens", 0);
    PxValue *events = array_of_strings(arena);
    px_arr_push(arena, events, px_str(arena, "run.started"));
    int tool_calls = 0;
    int steps = 0;
    long input_tokens = 0;
    long output_tokens = 0;
    const char *output = "";
    const char *error_code = NULL;
    size_t script_count = script == NULL ? 0 : script->as.array.len;
    for (int step = 1; step <= max_steps; step++) {
        if ((size_t)(step - 1) >= script_count) {
            error_code = "AGENT_SCRIPT";
            break;
        }
        PxValue *item = script->as.array.items[step - 1];
        input_tokens += (long)px_get_num(item, "inputTokens", 0);
        output_tokens += (long)px_get_num(item, "outputTokens", 0);
        if (max_tokens > 0 && input_tokens + output_tokens > max_tokens) {
            error_code = "AGENT_MAX_TOKENS";
            break;
        }
        PxValue *calls = px_obj_get(item, "toolCalls");
        if (calls == NULL || calls->as.array.len == 0) {
            output = px_get_str(item, "content");
            if (output == NULL) {
                output = "";
            }
            steps = step;
            px_arr_push(arena, events, px_str(arena, "run.completed"));
            break;
        }
        for (size_t index = 0; index < calls->as.array.len; index++) {
            PxValue *call = calls->as.array.items[index];
            const char *name = px_get_str(call, "name");
            if (name != NULL && (tools == NULL || tool_exists(tools, name))) {
                tool_calls++;
                px_arr_push(arena, events, px_str(arena, "tool.call"));
            }
        }
        if (step == max_steps) {
            error_code = "AGENT_MAX_STEPS";
        }
    }
    if (error_code != NULL) {
        px_arr_push(arena, events, px_str(arena, "run.failed"));
    }
    bool has_error = error_code != NULL;
    if (px_get_bool(expect, "error", false) != has_error) {
        return check(false, "agent error mismatch");
    }
    if (has_error) {
        const char *want = px_get_str(expect, "errorCode");
        if (!check(want != NULL && strcmp(want, error_code) == 0,
                   "agent errorCode mismatch")) {
            return false;
        }
    } else {
        const char *want_output = px_get_str(expect, "output");
        if (!check(want_output != NULL && strcmp(output, want_output) == 0,
                   "agent output mismatch")) {
            return false;
        }
        if (!check(steps == (int)px_get_num(expect, "steps", 0),
                   "agent steps mismatch")) {
            return false;
        }
    }
    if (!check(tool_calls == (int)px_get_num(expect, "toolInvocations", 0),
               "agent tool invocations mismatch")) {
        return false;
    }
    return check(px_equals(events, px_obj_get(expect, "events")),
                 "agent events mismatch");
}

bool px_run_agent_loop(PxArena *arena, PxValue *input, PxValue *expect) {
    return run_agent(arena, input, expect);
}
