#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

typedef struct {
    const char *target;
    int effects;
    int model_calls;
} State;

static PxValue *fixture_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)tools;
    State *state = ctx;
    state->model_calls++;
    PxValue *last = NULL;
    if (messages != NULL && messages->type == PX_ARR
            && messages->as.array.len > 0) {
        last = messages->as.array.items[messages->as.array.len - 1];
    }
    const char *role = last == NULL ? NULL : px_get_str(last, "role");
    if (role != NULL && strcmp(role, "tool") == 0) {
        return px_parse(arena, "{\"content\":\"recorded\"}");
    }
    PxValue *arguments = px_obj(arena);
    px_obj_set(arena, arguments, "target", px_str(arena, state->target));
    PxValue *call = px_obj(arena);
    px_obj_set(arena, call, "id", px_str(arena, "record-1"));
    px_obj_set(arena, call, "name", px_str(arena, "record"));
    px_obj_set(arena, call, "arguments", arguments);
    PxValue *calls = px_arr(arena);
    px_arr_push(arena, calls, call);
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, ""));
    px_obj_set(arena, response, "toolCalls", calls);
    return response;
}

static PxValue *record_tool(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arguments;
    State *state = ctx;
    if (name != NULL && strcmp(name, "record") == 0) {
        state->effects++;
        return px_str(arena, "recorded");
    }
    return NULL;
}

static const char *authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)ctx;
    if (strcmp(kind, "model.generate") == 0) {
        return NULL;
    }
    if (strcmp(kind, "tool.invoke") != 0) {
        return "AGENT_POLICY_DENIED";
    }
    const char *target = arguments == NULL ? NULL
        : px_get_str(arguments, "target");
    if (tool_name != NULL && strcmp(tool_name, "record") == 0
            && target != NULL && strcmp(target, "public") == 0) {
        return NULL;
    }
    return "AGENT_POLICY_DENIED";
}

static const char *allowed_tools[] = {"record"};

static const char *run_case(PxArena *arena, const char *target,
        PxAgentResult *result, int *effects) {
    State state = {target, 0, 0};
    PxAgentOptions options = {
        .generate = fixture_model,
        .invoke = record_tool,
        .ctx = &state,
        .max_steps = 3,
        .authorize = authorize,
        .allowed_tools = allowed_tools,
        .allowed_tools_count = 1,
    };
    const char *error = px_agent_run(arena, &options, NULL,
        "Record the requested target.", result);
    *effects = state.effects;
    return error;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxAgentResult result;
    int effects = 0;
    const char *error = run_case(&arena, "public", &result, &effects);
    if (error != NULL || strcmp(result.output, "recorded") != 0
            || effects != 1) {
        fprintf(stderr, "allow verification failed: output=%s effects=%d error=%s\n",
            result.output, effects, error == NULL ? "" : error);
        px_arena_free(&arena);
        return 1;
    }
    printf("allow: recorded; effects=%d\n", effects);

    error = run_case(&arena, "private", &result, &effects);
    if (error == NULL || strcmp(error, "AGENT_POLICY_DENIED") != 0
            || effects != 0) {
        fprintf(stderr, "deny verification failed: effects=%d error=%s\n",
            effects, error == NULL ? "" : error);
        px_arena_free(&arena);
        return 1;
    }
    printf("deny: policy rejected; effects=%d\n", effects);

    px_arena_free(&arena);
    return 0;
}
