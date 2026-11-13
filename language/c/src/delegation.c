#include "delegation.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

PxSubagentRequest px_subagent_request(const char *parent_session_id,
        const char *agent_id, const char *prompt) {
    PxSubagentRequest request;
    request.parent_session_id = parent_session_id == NULL ? "" : parent_session_id;
    request.agent_id = agent_id == NULL ? "" : agent_id;
    request.prompt = prompt == NULL ? "" : prompt;
    request.context = NULL;
    request.mode = "isolated";
    request.history = NULL;
    return request;
}

static const char *now_iso(PxArena *arena) {
    time_t now = time(NULL);
    struct tm value;
#ifdef _WIN32
    gmtime_s(&value, &now);
#else
    gmtime_r(&now, &value);
#endif
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%04d-%02d-%02dT%02d:%02d:%02dZ",
        value.tm_year + 1900, value.tm_mon + 1, value.tm_mday,
        value.tm_hour, value.tm_min, value.tm_sec);
    return px_arena_strdup(arena, buffer);
}

PxSubagentTask *px_subagent_run(PxArena *arena, PxSubagentRunner runner,
        void *ctx, const PxSubagentRequest *request, const char **error) {
    if (error != NULL) {
        *error = NULL;
    }
    if (arena == NULL || runner == NULL || request == NULL) {
        if (error != NULL) {
            *error = "SUBAGENT_INVALID";
        }
        return NULL;
    }
    if (request->parent_session_id == NULL || request->parent_session_id[0] == '\0'
            || request->agent_id == NULL || request->agent_id[0] == '\0') {
        if (error != NULL) {
            *error = "SUBAGENT_INVALID";
        }
        return NULL;
    }
    PxSubagentTask *task = px_arena_alloc(arena, sizeof(PxSubagentTask));
    if (task == NULL) {
        if (error != NULL) {
            *error = "SUBAGENT_INVALID";
        }
        return NULL;
    }
    char identifier[64];
    snprintf(identifier, sizeof(identifier), "subagent-%lld",
        (long long)time(NULL));
    task->id = px_arena_strdup(arena, identifier);
    task->parent_session_id = px_arena_strdup(arena, request->parent_session_id);
    task->agent_id = px_arena_strdup(arena, request->agent_id);
    task->mode = px_arena_strdup(arena,
        request->mode != NULL && strcmp(request->mode, "fork") == 0
            ? "fork" : "isolated");
    task->status = "running";
    task->output = "";
    task->error = "";
    task->created_at = now_iso(arena);
    task->updated_at = task->created_at;

    PxSubagentResult result;
    memset(&result, 0, sizeof(result));
    const char *runner_error = NULL;
    if (runner(arena, request, ctx, &result, &runner_error)) {
        task->status = "completed";
        task->output = result.output == NULL ? "" : result.output;
    } else {
        task->status = "failed";
        task->error = runner_error == NULL ? "subagent failed" : runner_error;
    }
    task->updated_at = now_iso(arena);
    return task;
}
