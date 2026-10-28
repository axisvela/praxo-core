#include "vectors_agent.h"
#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

static bool check(bool condition, const char *detail) {
    if (!condition) {
        fprintf(stderr, "  %s\n", detail);
    }
    return condition;
}

static const char **strings(PxArena *arena, PxValue *array, size_t *count) {
    *count = array == NULL ? 0 : array->as.array.len;
    const char **out = px_arena_alloc(arena, sizeof(char *) * (*count + 1));
    for (size_t index = 0; index < *count; index++) {
        out[index] = array->as.array.items[index]->as.string;
    }
    return out;
}

static char *repair(PxArena *arena, const char *text, void *ctx) {
    (void)text;
    return px_arena_strdup(arena, ctx);
}

bool px_run_middleware(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *operation = px_get_str(input, "operation");
    if (operation == NULL) {
        return false;
    }
    if (strcmp(operation, "pii") == 0) {
        const char *text = px_get_str(input, "text");
        return check(strcmp(px_pii_redact(arena, text == NULL ? "" : text),
            px_get_str(expect, "text")) == 0, "pii text mismatch");
    }
    if (strcmp(operation, "pii-value") == 0) {
        return check(px_equals(px_redact_value(arena, px_obj_get(input, "value")),
            px_obj_get(expect, "value")), "pii value mismatch");
    }
    if (strcmp(operation, "structured") == 0) {
        const char *replacement = px_get_str(input, "repairOutput");
        PxStructuredOutput config = {px_obj_get(input, "schema"),
            (int)px_get_num(input, "maxRepairs", 0),
            replacement == NULL ? NULL : repair, (void *)replacement};
        char *output = px_apply_structured(arena, &config, px_get_str(input, "output"));
        if (!check((output != NULL) == px_get_bool(expect, "ok", false),
                "structured ok mismatch")) {
            return false;
        }
        if (output == NULL) {
            return check(strcmp(px_get_str(expect, "errorCode"),
                "AGENT_STRUCTURED_OUTPUT") == 0, "structured failure mismatch");
        }
        return check(strcmp(output, px_get_str(expect, "output")) == 0,
            "structured output mismatch");
    }
    if (strcmp(operation, "call-limit") == 0) {
        PxCallLimit limit;
        px_call_limit_init(&limit, (int)px_get_num(input, "modelLimit", 0),
            (int)px_get_num(input, "toolLimit", 0));
        PxValue *calls = px_obj_get(input, "calls");
        PxValue *outcomes = px_arr(arena);
        for (size_t index = 0; calls != NULL && index < calls->as.array.len; index++) {
            const char *kind = calls->as.array.items[index]->as.string;
            const char *code = NULL;
            if (strcmp(kind, "model") == 0) {
                code = px_call_limit_model(&limit);
            } else if (strcmp(kind, "tool") == 0) {
                code = px_call_limit_tool(&limit);
            } else {
                return check(false, "unsupported call kind");
            }
            px_arr_push(arena, outcomes, px_str(arena, code == NULL ? "ok" : code));
        }
        return check(px_equals(outcomes, px_obj_get(expect, "outcomes")), "outcomes mismatch");
    }
    if (strcmp(operation, "tool-selection") == 0) {
        size_t selection_count, tool_count;
        const char **selection = strings(arena, px_obj_get(input, "selected"), &selection_count);
        const char **tools = strings(arena, px_obj_get(input, "tools"), &tool_count);
        const char **out = NULL;
        size_t count = px_select_tools(arena, selection, selection_count, tools, tool_count, &out);
        PxValue *advertised = px_arr(arena);
        for (size_t index = 0; index < count; index++) {
            px_arr_push(arena, advertised, px_str(arena, out[index]));
        }
        const char *code = px_check_tool_selected(selection, selection_count,
            px_get_str(input, "requested"));
        return check(px_equals(advertised, px_obj_get(expect, "advertised")), "advertised mismatch")
            && check(strcmp(code == NULL ? "ok" : code, px_get_str(expect, "reject")) == 0,
                "selection rejection mismatch");
    }
    if (strcmp(operation, "fallback") == 0) {
        return check(strcmp(px_fallback(NULL, px_get_str(input, "fallbackContent"), true),
            px_get_str(expect, "output")) == 0, "fallback output mismatch");
    }
    return check(false, "unsupported middleware operation");
}

typedef struct {
    PxArena *arena;
    PxValue *script;
    PxValue *events;
    PxValue *tools;
    size_t next;
    int invocations;
    bool unknown_tool;
} Script;

static PxValue *generate(PxArena *arena, PxValue *messages, PxValue *tools, void *ctx) {
    (void)arena;
    (void)messages;
    (void)tools;
    Script *script = ctx;
    if (script->script == NULL || script->next >= script->script->as.array.len) {
        return NULL;
    }
    return script->script->as.array.items[script->next++];
}

static PxValue *invoke(PxArena *arena, const char *name, PxValue *arguments, void *ctx) {
    (void)arena;
    Script *script = ctx;
    for (size_t index = 0; script->tools != NULL && index < script->tools->as.array.len; index++) {
        const char *registered = px_get_str(script->tools->as.array.items[index], "name");
        if (registered != NULL && strcmp(registered, name) == 0) {
            script->invocations++;
            return arguments;
        }
    }
    script->unknown_tool = true;
    return NULL;
}

static void emit(const char *kind, void *ctx) {
    Script *script = ctx;
    px_arr_push(script->arena, script->events, px_str(script->arena, kind));
}

bool px_run_agent_loop(PxArena *arena, PxValue *input, PxValue *expect) {
    Script script = {arena, px_obj_get(input, "script"), px_arr(arena),
        px_obj_get(input, "tools"), 0, 0, false};
    PxAgentOptions options = {generate, invoke, emit, &script,
        (int)px_get_num(input, "maxSteps", 0), (long)px_get_num(input, "maxTokens", 0)};
    PxAgentResult result;
    const char *code = px_agent_run(arena, &options, px_obj_get(input, "messages"),
        px_get_str(input, "prompt"), &result);
    if (!check((code != NULL) == px_get_bool(expect, "error", false), "agent error mismatch")) {
        return false;
    }
    if (code != NULL) {
        if (!check(strcmp(code, px_get_str(expect, "errorCode")) == 0, "agent code mismatch")) {
            return false;
        }
    } else if (!check(strcmp(result.output, px_get_str(expect, "output")) == 0,
            "agent output mismatch")
            || !check(result.steps == (int)px_get_num(expect, "steps", 0), "agent steps mismatch")) {
        return false;
    }
    return check(!script.unknown_tool, "fixture invoked an unregistered fake tool")
        && check(script.invocations == (int)px_get_num(expect, "toolInvocations", 0),
        "agent tool invocations mismatch")
        && check(px_equals(script.events, px_obj_get(expect, "events")), "agent events mismatch");
}
