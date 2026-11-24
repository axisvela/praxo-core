#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

#define BUILDING_ID "building-100"

typedef struct {
    const char *building;
    int reads;
    int simulate_failure;
} BuildingState;

typedef struct {
    BuildingState state;
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
        px_obj_set(arena, arguments, "building_id",
            px_str(arena, tutorial->state.building));
        return call_response(arena, "building-1", "read_building", arguments);
    }
    PxValue *building = first == NULL ? NULL : px_parse(arena, first);
    if (building != NULL && px_get_str(building, "error") != NULL) {
        return final_response(arena, px_get_str(building, "error"));
    }
    PxValue *report = px_obj(arena);
    px_obj_set(arena, report, "stage", px_str(arena, "settings_drafted"));
    px_obj_set(arena, report, "building", building);
    PxValue *settings = px_obj(arena);
    px_obj_set(arena, settings, "settings_id", px_str(arena, "settings-100"));
    px_obj_set(arena, settings, "cooling_setpoint_c", px_num(arena, 23));
    px_obj_set(arena, settings, "lighting_percent", px_num(arena, 60));
    px_obj_set(arena, settings, "status", px_str(arena, "draft_only"));
    px_obj_set(arena, settings, "review_required", px_bool(arena, true));
    px_obj_set(arena, settings, "bms_commands", px_num(arena, 0));
    px_obj_set(arena, report, "settings", settings);
    px_obj_set(arena, report, "energy_savings_claim", px_bool(arena, false));
    return final_response(arena, px_stringify(arena, report));
}

static PxValue *dispatch_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arguments;
    TutorialContext *tutorial = ctx;
    if (name == NULL || strcmp(name, "read_building") != 0) {
        return NULL;
    }
    tutorial->state.reads++;
    if (tutorial->state.simulate_failure) {
        PxValue *failure = px_obj(arena);
        px_obj_set(arena, failure, "error", px_str(arena, "BUILDING_DATA_UNAVAILABLE"));
        return failure;
    }
    PxValue *building = px_obj(arena);
    px_obj_set(arena, building, "building", px_str(arena, BUILDING_ID));
    px_obj_set(arena, building, "occupancy", px_num(arena, 40));
    px_obj_set(arena, building, "temperature_c", px_num(arena, 24.5));
    px_obj_set(arena, building, "setpoint_c", px_num(arena, 22));
    px_obj_set(arena, building, "co2_ppm", px_num(arena, 900));
    px_obj_set(arena, building, "source", px_str(arena, "building_fixture"));
    return building;
}

static const char *authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)ctx;
    if (strcmp(kind, "model.generate") == 0) return NULL;
    if (strcmp(kind, "tool.invoke") != 0) return "AGENT_POLICY_DENIED";
    const char *building = arguments == NULL ? NULL
        : px_get_str(arguments, "building_id");
    const int in_scope = building != NULL && strcmp(building, BUILDING_ID) == 0;
    if (tool_name != NULL && strcmp(tool_name, "read_building") == 0) {
        return in_scope ? NULL : "AGENT_POLICY_DENIED";
    }
    return "AGENT_POLICY_DENIED";
}

static const char *run_scenario(PxArena *arena, const char *building,
        int simulate_failure, PxAgentResult *result, int *reads) {
    TutorialContext tutorial;
    memset(&tutorial, 0, sizeof(tutorial));
    tutorial.state.building = building;
    tutorial.state.simulate_failure = simulate_failure;
    static const char *allowed[] = {"read_building"};
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
        "Read fixed building conditions and draft review-only settings.", result);
    *reads = tutorial.state.reads;
    return error;
}

static int run_tests(PxArena *arena) {
    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(arena, BUILDING_ID, 0, &result, &reads);
    if (error != NULL) {
        fprintf(stderr, "success path failed: %s\n", error);
        return 1;
    }
    PxValue *report = px_parse(arena, result.output);
    PxValue *building = report == NULL ? NULL : px_obj_get(report, "building");
    PxValue *settings = report == NULL ? NULL : px_obj_get(report, "settings");
    if (building == NULL || settings == NULL
            || px_get_num(building, "occupancy", 0) != 40
            || px_get_num(building, "temperature_c", 0) != 24.5
            || strcmp(px_get_str(settings, "status"), "draft_only") != 0
            || px_get_num(settings, "bms_commands", 1) != 0 || reads != 1) {
        fprintf(stderr, "success verification failed: reads=%d\n", reads);
        return 1;
    }
    printf("success: building-100 occupancy=40 status=draft_only bms_commands=0 reads=1\n");

    int denied_reads = 0;
    error = run_scenario(arena, "building-200", 0, &result, &denied_reads);
    if (error == NULL || strcmp(error, "AGENT_POLICY_DENIED") != 0
            || denied_reads != 0) {
        fprintf(stderr, "deny verification failed\n");
        return 1;
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    int failure_reads = 0;
    error = run_scenario(arena, BUILDING_ID, 1, &result, &failure_reads);
    if (error != NULL || result.output == NULL
            || strcmp(result.output, "BUILDING_DATA_UNAVAILABLE") != 0
            || failure_reads != 1) {
        fprintf(stderr, "failure verification failed\n");
        return 1;
    }
    printf("failure: BUILDING_DATA_UNAVAILABLE reads=1\n");
    return 0;
}

int main(int argc, char **argv) {
    PxArena arena;
    px_arena_init(&arena);
    int test_mode = 0;
    int simulate_failure = 0;
    const char *building = BUILDING_ID;
    for (int index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--test") == 0) {
            test_mode = 1;
        } else if (strcmp(argv[index], "--simulate-failure") == 0) {
            simulate_failure = 1;
        } else if (strcmp(argv[index], "--building") == 0 && index + 1 < argc) {
            building = argv[++index];
        }
    }
    if (test_mode) {
        int status = run_tests(&arena);
        px_arena_free(&arena);
        return status;
    }
    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(&arena, building, simulate_failure, &result, &reads);
    if (error != NULL) {
        fprintf(stderr, "error: %s reads=%d\n", error, reads);
        px_arena_free(&arena);
        return strcmp(error, "AGENT_POLICY_DENIED") == 0 ? 2 : 1;
    }
    printf("%s\nreads=%d\n", result.output, reads);
    const int failed = result.output != NULL
        && strcmp(result.output, "BUILDING_DATA_UNAVAILABLE") == 0;
    px_arena_free(&arena);
    return failed ? 1 : 0;
}
