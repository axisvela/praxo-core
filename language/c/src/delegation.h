#ifndef PRAXO_DELEGATION_H
#define PRAXO_DELEGATION_H

#include <stdbool.h>
#include <stddef.h>

#include "praxo.h"

typedef struct {
    const char *parent_session_id;
    const char *agent_id;
    const char *prompt;
    PxValue *context;
    const char *mode;
    PxValue *history;
} PxSubagentRequest;

typedef struct {
    const char *task_id;
    const char *agent_id;
    const char *output;
    PxValue *usage;
} PxSubagentResult;

typedef struct {
    const char *id;
    const char *parent_session_id;
    const char *agent_id;
    const char *mode;
    const char *status;
    const char *output;
    const char *error;
    const char *created_at;
    const char *updated_at;
} PxSubagentTask;

typedef bool (*PxSubagentRunner)(PxArena *arena,
    const PxSubagentRequest *request, void *ctx, PxSubagentResult *result,
    const char **error);

PxSubagentRequest px_subagent_request(const char *parent_session_id,
    const char *agent_id, const char *prompt);

PxSubagentTask *px_subagent_run(PxArena *arena, PxSubagentRunner runner,
    void *ctx, const PxSubagentRequest *request, const char **error);

#endif
