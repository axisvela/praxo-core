#include "delegation.h"

#include <assert.h>
#include <string.h>

static bool success_runner(PxArena *arena, const PxSubagentRequest *request,
        void *ctx, PxSubagentResult *result, const char **error) {
    (void)arena;
    (void)request;
    (void)ctx;
    if (error != NULL) {
        *error = NULL;
    }
    result->output = "done";
    return true;
}

static bool failure_runner(PxArena *arena, const PxSubagentRequest *request,
        void *ctx, PxSubagentResult *result, const char **error) {
    (void)arena;
    (void)request;
    (void)ctx;
    (void)result;
    if (error != NULL) {
        *error = "boom";
    }
    return false;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxSubagentRequest request = px_subagent_request("parent", "child", "do");
    request.mode = "fork";
    const char *error = NULL;
    PxSubagentTask *task = px_subagent_run(&arena, success_runner, NULL,
        &request, &error);
    assert(error == NULL);
    assert(strcmp(task->status, "completed") == 0);
    assert(strcmp(task->output, "done") == 0);
    assert(strcmp(task->mode, "fork") == 0);

    PxSubagentTask *failed = px_subagent_run(&arena, failure_runner, NULL,
        &request, &error);
    assert(failed != NULL);
    assert(strcmp(failed->status, "failed") == 0);
    assert(strcmp(failed->error, "boom") == 0);

    PxSubagentRequest invalid = px_subagent_request("", "child", "do");
    error = NULL;
    assert(px_subagent_run(&arena, success_runner, NULL, &invalid, &error) == NULL);
    assert(strcmp(error, "SUBAGENT_INVALID") == 0);

    px_arena_free(&arena);
    return 0;
}
