#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

#define DEVICE_ID "device-100"

typedef PxValue *(*PxDeviceRead)(PxArena *arena, const char *device, void *ctx);

typedef struct {
    PxDeviceRead read;
    void *ctx;
} PxDeviceAdapter;

typedef struct {
    const char *device;
    int reads;
    int writes;
    int simulate_failure;
} DeviceState;

typedef struct {
    PxDeviceAdapter adapter;
    DeviceState state;
} TutorialContext;

static PxValue *fixture_read(PxArena *arena, const char *device, void *ctx) {
    DeviceState *state = ctx;
    state->reads++;
    if (state->simulate_failure) {
        PxValue *failure = px_obj(arena);
        px_obj_set(arena, failure, "error", px_str(arena, "DEVICE_READ_FAILED"));
        return failure;
    }
    PxValue *snapshot = px_obj(arena);
    px_obj_set(arena, snapshot, "device_id", px_str(arena, device));
    px_obj_set(arena, snapshot, "health", px_str(arena, "degraded"));
    px_obj_set(arena, snapshot, "uptime_s", px_num(arena, 86400));
    px_obj_set(arena, snapshot, "disk_percent", px_num(arena, 91));
    px_obj_set(arena, snapshot, "memory_percent", px_num(arena, 78));
    px_obj_set(arena, snapshot, "link", px_str(arena, "serial-bus"));
    px_obj_set(arena, snapshot, "source", px_str(arena, "adapter_fixture"));
    return snapshot;
}

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
    const char *second = NULL;
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
            const char *content = px_get_str(message, "content");
            if (tool_count == 0) {
                first = content;
            } else if (tool_count == 1) {
                second = content;
            }
            tool_count++;
        }
    }

    if (tool_count == 0) {
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, arguments, "device_id",
            px_str(arena, tutorial->state.device));
        return call_response(arena, "read-1", "read_device", arguments);
    }
    if (tool_count == 1) {
        PxValue *device = first == NULL ? NULL : px_parse(arena, first);
        if (device != NULL) {
            const char *failure = px_get_str(device, "error");
            if (failure != NULL) {
                return final_response(arena, failure);
            }
        }
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, arguments, "device_id",
            px_str(arena, tutorial->state.device));
        px_obj_set(arena, arguments, "action",
            px_str(arena, "notify_operator"));
        px_obj_set(arena, arguments, "reason",
            px_str(arena, "disk pressure and degraded health"));
        return call_response(arena, "draft-1", "draft_action", arguments);
    }

    PxValue *report = px_obj(arena);
    px_obj_set(arena, report, "device",
        px_parse(arena, first == NULL ? "null" : first));
    px_obj_set(arena, report, "draft",
        px_parse(arena, second == NULL ? "null" : second));
    px_obj_set(arena, report, "policy",
        px_str(arena,
            "read and draft only; device writes remain application-owned"));
    px_obj_set(arena, report, "device_writes", px_num(arena, 0));
    return final_response(arena, px_stringify(arena, report));
}

static PxValue *dispatch_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    TutorialContext *tutorial = ctx;
    if (name != NULL && strcmp(name, "read_device") == 0) {
        const char *device = arguments == NULL ? NULL
            : px_get_str(arguments, "device_id");
        if (device == NULL) {
            device = DEVICE_ID;
        }
        return tutorial->adapter.read(arena, device, tutorial->adapter.ctx);
    }
    if (name != NULL && strcmp(name, "draft_action") == 0) {
        const char *device = arguments == NULL ? NULL
            : px_get_str(arguments, "device_id");
        if (device == NULL) {
            device = DEVICE_ID;
        }
        const char *action = arguments == NULL ? NULL
            : px_get_str(arguments, "action");
        if (action == NULL) {
            action = "notify_operator";
        }
        PxValue *draft = px_obj(arena);
        px_obj_set(arena, draft, "draft_id", px_str(arena, "draft-100"));
        px_obj_set(arena, draft, "device_id", px_str(arena, device));
        px_obj_set(arena, draft, "action", px_str(arena, action));
        px_obj_set(arena, draft, "status", px_str(arena, "draft_only"));
        px_obj_set(arena, draft, "review_required", px_bool(arena, true));
        px_obj_set(arena, draft, "device_writes",
            px_num(arena, tutorial->state.writes));
        return draft;
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
    const char *device = arguments == NULL ? NULL
        : px_get_str(arguments, "device_id");
    const int in_scope = device != NULL && strcmp(device, DEVICE_ID) == 0;
    if (tool_name != NULL && strcmp(tool_name, "read_device") == 0) {
        return in_scope ? NULL : "AGENT_POLICY_DENIED";
    }
    if (tool_name != NULL && strcmp(tool_name, "draft_action") == 0) {
        const char *action = arguments == NULL ? NULL
            : px_get_str(arguments, "action");
        const int draft_ok = in_scope && action != NULL
            && strcmp(action, "notify_operator") == 0;
        return draft_ok ? NULL : "AGENT_POLICY_DENIED";
    }
    return "AGENT_POLICY_DENIED";
}

static const char *run_scenario(PxArena *arena, const char *device,
        int simulate_failure, PxAgentResult *result, int *reads) {
    TutorialContext tutorial;
    memset(&tutorial, 0, sizeof(tutorial));
    tutorial.state.device = device;
    tutorial.state.simulate_failure = simulate_failure;
    tutorial.adapter.read = fixture_read;
    tutorial.adapter.ctx = &tutorial.state;

    static const char *allowed[] = {"read_device", "draft_action"};
    PxAgentOptions options;
    memset(&options, 0, sizeof(options));
    options.generate = fixture_model;
    options.invoke = dispatch_invoke;
    options.authorize = authorize;
    options.ctx = &tutorial;
    options.max_steps = 5;
    options.allowed_tools = (const char *const *)allowed;
    options.allowed_tools_count = 2;
    options.require_policy = true;
    options.require_tool_scope = true;

    const char *error = px_agent_run(arena, &options, NULL,
        "Diagnose the fixed device and draft an operator review action.",
        result);
    *reads = tutorial.state.reads;
    return error;
}

static int expect_device(const PxValue *device) {
    const char *health = px_get_str(device, "health");
    return health != NULL && strcmp(health, "degraded") == 0
        && px_get_num(device, "disk_percent", 0) == 91;
}

static int run_tests(PxArena *arena) {
    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(arena, DEVICE_ID, 0, &result, &reads);
    if (error != NULL) {
        fprintf(stderr, "success path failed: %s\n", error);
        return 1;
    }
    PxValue *report = px_parse(arena, result.output);
    PxValue *device = report == NULL ? NULL : px_obj_get(report, "device");
    PxValue *draft = report == NULL ? NULL : px_obj_get(report, "draft");
    const char *status = draft == NULL ? NULL : px_get_str(draft, "status");
    const char *action = draft == NULL ? NULL : px_get_str(draft, "action");
    if (device == NULL || !expect_device(device) || status == NULL
            || strcmp(status, "draft_only") != 0 || action == NULL
            || strcmp(action, "notify_operator") != 0
            || px_get_num(report, "device_writes", 1) != 0 || reads != 1) {
        fprintf(stderr, "success verification failed: reads=%d\n", reads);
        return 1;
    }
    printf("success: device-100 health=degraded action=notify_operator "
        "status=draft_only writes=0 reads=1\n");

    int denied_reads = 0;
    error = run_scenario(arena, "device-200", 0, &result, &denied_reads);
    if (error == NULL || strcmp(error, "AGENT_POLICY_DENIED") != 0
            || denied_reads != 0) {
        fprintf(stderr, "deny verification failed: reads=%d error=%s\n",
            denied_reads, error == NULL ? "" : error);
        return 1;
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    int failure_reads = 0;
    error = run_scenario(arena, DEVICE_ID, 1, &result, &failure_reads);
    if (error != NULL || result.output == NULL
            || strcmp(result.output, "DEVICE_READ_FAILED") != 0
            || failure_reads != 1) {
        fprintf(stderr, "failure verification failed: reads=%d output=%s\n",
            failure_reads, result.output == NULL ? "" : result.output);
        return 1;
    }
    printf("failure: DEVICE_READ_FAILED reads=1\n");
    return 0;
}

int main(int argc, char **argv) {
    PxArena arena;
    px_arena_init(&arena);

    int test_mode = 0;
    int simulate_failure = 0;
    const char *device = DEVICE_ID;
    for (int index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--test") == 0) {
            test_mode = 1;
        } else if (strcmp(argv[index], "--simulate-failure") == 0) {
            simulate_failure = 1;
        } else if (strcmp(argv[index], "--device") == 0 && index + 1 < argc) {
            device = argv[++index];
        }
    }

    if (test_mode) {
        int status = run_tests(&arena);
        px_arena_free(&arena);
        return status;
    }

    PxAgentResult result;
    int reads = 0;
    const char *error = run_scenario(&arena, device, simulate_failure, &result,
        &reads);
    if (error != NULL) {
        fprintf(stderr, "error: %s reads=%d\n", error, reads);
        px_arena_free(&arena);
        return strcmp(error, "AGENT_POLICY_DENIED") == 0 ? 2 : 1;
    }
    printf("%s\nreads=%d\n", result.output, reads);
    const int failed = result.output != NULL
        && strcmp(result.output, "DEVICE_READ_FAILED") == 0;
    px_arena_free(&arena);
    return failed ? 1 : 0;
}
