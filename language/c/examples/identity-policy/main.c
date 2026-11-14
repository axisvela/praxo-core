#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    const char *tenant;
    const char *role;
    int active;
} Principal;

static const char *authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    Principal *principal = ctx;
    if (principal == NULL) return "AGENT_POLICY_DENIED";
    if (!principal->active) return "AGENT_POLICY_DENIED";
    if (strcmp(kind, "model.generate") == 0) return NULL;
    if (strcmp(principal->role, "operator") != 0) return "AGENT_POLICY_DENIED";
    const char *tenant = px_get_str(arguments, "tenant");
    if (tenant == NULL || strcmp(tenant, principal->tenant) != 0) {
        return "AGENT_POLICY_DENIED";
    }
    if (tool_name == NULL || strcmp(tool_name, "record") != 0) {
        return "AGENT_POLICY_DENIED";
    }
    return NULL;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxValue *arguments = px_obj(&arena);
    px_obj_set(&arena, arguments, "tenant", px_str(&arena, "acme"));

    Principal operator = {"acme", "operator", 1};
    Principal viewer = {"acme", "viewer", 1};
    Principal inactive = {"acme", "operator", 0};

    assert(authorize("model.generate", "s1", NULL, arguments, &operator) == NULL);
    assert(authorize("tool.invoke", "s1", "record", arguments, &operator) == NULL);
    assert(authorize("tool.invoke", "s1", "record", arguments, &viewer) != NULL);
    assert(authorize("tool.invoke", "s1", "record", arguments, &inactive) != NULL);
    assert(authorize("model.generate", "s1", NULL, arguments, NULL) != NULL);

    px_arena_free(&arena);
    printf("C identity policy example passed\n");
    return 0;
}
