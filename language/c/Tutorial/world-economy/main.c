#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

#define WORLD_ID "world-100"

typedef struct {
    const char *world;
    int reads;
    int simulate_failure;
} WorldState;

typedef struct {
    WorldState state;
} TutorialContext;

static PxValue *call_response(PxArena *arena, const char *id, const char *name,
        PxValue *arguments) {
    PxValue *call = px_obj(arena);
    px_obj_set(arena, call, "id", px_str(arena, id));
    px_obj_set(arena, call, "name", px_str(arena, name));
    px_obj_set(arena, call, "arguments", arguments);
    PxValue *calls = px_arr(arena);
    px_arr_push(arena, calls, call);
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, ""));
    px_obj_set(arena, response, "toolCalls", calls);
    return response;
}

static PxValue *final_response(PxArena *arena, const char *text) {
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, text));
    return response;
}

static PxValue *fixture_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)tools;
    TutorialContext *tutorial = ctx;
    const char *first = NULL;
    int tool_count = 0;
    if (messages != NULL && messages->type == PX_ARR) {
        for (size_t index = 0; index < messages->as.array.len; index++) {
            PxValue *message = messages->as.array.items[index];
            if (message == NULL || message->type != PX_OBJ) {
                continue;
            }
            const char *role = px_get_str(message, "role");
            if (role == NULL || strcmp(role, "tool") != 0) {
                continue;
            }
            if (tool_count == 0) {
                first = px_get_str(message, "content");
            }
            tool_count++;
        }
    }
    if (tool_count == 0) {
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, arguments, "world_id", px_str(arena, tutorial->state.world));
        return call_response(arena, "tick-1", "simulate_tick", arguments);
    }
    PxValue *tick = first == NULL ? NULL : px_parse(arena, first);
    if (tick != NULL && px_get_str(tick, "error") != NULL) {
        return final_response(arena, px_get_str(tick, "error"));
    }
    PxValue *report = px_obj(arena);
    px_obj_set(arena, report, "stage", px_str(arena, "balance_review_drafted"));
    px_obj_set(arena, report, "tick", tick);
    PxValue *balance = px_obj(arena);
    px_obj_set(arena, balance, "balance_id", px_str(arena, "balance-100"));
    px_obj_set(arena, balance, "action", px_str(arena, "review_price_adjustment"));
    px_obj_set(arena, balance, "status", px_str(arena, "draft_only"));
    px_obj_set(arena, balance, "review_required", px_bool(arena, true));
    px_obj_set(arena, balance, "economy_writes", px_num(arena, 0));
    px_obj_set(arena, report, "balance", balance);
    px_obj_set(arena, report, "equilibrium_guarantee", px_bool(arena, false));
    return final_response(arena, px_stringify(arena, report));
}

static PxValue *dispatch_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arguments;
    TutorialContext *tutorial = ctx;
    if (name == NULL || strcmp(name, "simulate_tick") != 0) {
        return NULL;
    }
    tutorial->state.reads++;
    if (tutorial->state.simulate_failure) {
        PxValue *failure = px_obj(arena);
        px_obj_set(arena, failure, "error", px_str(arena, "ECONOMY_TICK_UNAVAILABLE"));
        return failure;
    }
    PxValue *tick = px_obj(arena);
    px_obj_set(arena, tick, "world", px_str(arena, WORLD_ID));
    px_obj_set(arena, tick, "tick", px_num(arena, 1));
    px_obj_set(arena, tick, "supply", px_num(arena, 100));
    px_obj_set(arena, tick, "demand", px_num(arena, 115));
    px_obj_set(arena, tick, "price", px_num(arena, 12.5));
    px_obj_set(arena, tick, "source", px_str(arena, "economy_fixture"));
    return tick;
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
    const char *world = arguments == NULL ? NULL : px_get_str(arguments, "world_id");
    const int in_scope = world != NULL && strcmp(world, WORLD_ID) == 0;
    if (tool_name != NULL && strcmp(tool_name, "simulate_tick") == 0) {
        return in_scope ? NULL : "AGENT_POLICY_DENIED";
    }
    return "AGENT_POLICY_DENIED";
}

static const char *run_scenario(PxArena *arena, const char *world,
        int simulate_failure, PxAgentResult *result, int *reads) {
    TutorialContext tutorial;
    memset(&tutorial, 0, sizeof(tutorial));
    tutorial.state.world = world;
    tutorial.state.simulate_failure = simulate_failure;
    static const char *allowed[] = {"simulate_tick"};
    PxAgentOptions options;
    memset(&options, 0, sizeof(options));
    options.generate = fixture_model;
    options.invoke = dispatch_invoke;
    options.authorize = authorize;
    options.ctx = &tutorial;
    options.max_steps = 4;
    options.allowed_tools = (const char *const *)allowed;
    options.allowed_tools_count = 1;
    options.require_policy = true;
    options.require_tool_scope = true;
    const char *error = px_agent_run(arena, &options, NULL,
        "Simulate one fixed world tick and draft a review-only balance action.", result);
    *reads = tutorial.state.reads;
    return error;
}

static int run_tests(PxArena *arena) {
    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(arena, WORLD_ID, 0, &result, &reads);
    if (error != NULL) {
        fprintf(stderr, "success path failed: %s\n", error);
        return 1;
    }
    PxValue *report = px_parse(arena, result.output);
    PxValue *tick = report == NULL ? NULL : px_obj_get(report, "tick");
    PxValue *balance = report == NULL ? NULL : px_obj_get(report, "balance");
    if (tick == NULL || balance == NULL
            || px_get_num(tick, "demand", 0) != 115
            || px_get_num(tick, "price", 0) != 12.5
            || strcmp(px_get_str(balance, "status"), "draft_only") != 0
            || px_get_num(balance, "economy_writes", 1) != 0 || reads != 1) {
        fprintf(stderr, "success verification failed: reads=%d\n", reads);
        return 1;
    }
    printf("success: world-100 demand=115 status=draft_only writes=0 reads=1\n");

    int denied_reads = 0;
    error = run_scenario(arena, "world-200", 0, &result, &denied_reads);
    if (error == NULL || strcmp(error, "AGENT_POLICY_DENIED") != 0
            || denied_reads != 0) {
        fprintf(stderr, "deny verification failed\n");
        return 1;
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    int failure_reads = 0;
    error = run_scenario(arena, WORLD_ID, 1, &result, &failure_reads);
    if (error != NULL || result.output == NULL
            || strcmp(result.output, "ECONOMY_TICK_UNAVAILABLE") != 0
            || failure_reads != 1) {
        fprintf(stderr, "failure verification failed\n");
        return 1;
    }
    printf("failure: ECONOMY_TICK_UNAVAILABLE reads=1\n");
    return 0;
}

int main(int argc, char **argv) {
    PxArena arena;
    px_arena_init(&arena);
    int test_mode = 0;
    int simulate_failure = 0;
    const char *world = WORLD_ID;
    for (int index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--test") == 0) {
            test_mode = 1;
        } else if (strcmp(argv[index], "--simulate-failure") == 0) {
            simulate_failure = 1;
        } else if (strcmp(argv[index], "--world") == 0 && index + 1 < argc) {
            world = argv[++index];
        }
    }
    if (test_mode) {
        int status = run_tests(&arena);
        px_arena_free(&arena);
        return status;
    }
    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(&arena, world, simulate_failure, &result, &reads);
    if (error != NULL) {
        fprintf(stderr, "error: %s reads=%d\n", error, reads);
        px_arena_free(&arena);
        return strcmp(error, "AGENT_POLICY_DENIED") == 0 ? 2 : 1;
    }
    printf("%s\nreads=%d\n", result.output, reads);
    const int failed = result.output != NULL
        && strcmp(result.output, "ECONOMY_TICK_UNAVAILABLE") == 0;
    px_arena_free(&arena);
    return failed ? 1 : 0;
}
