#include "vectors_core.h"
#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

static bool check(bool condition, const char *detail) {
    if (!condition) {
        fprintf(stderr, "  %s\n", detail);
    }
    return condition;
}

bool px_run_policy(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *grants = px_obj_get(input, "grants");
    size_t count = grants == NULL ? 0 : grants->as.array.len;
    PxPathGrant *converted = px_arena_alloc(arena, sizeof(PxPathGrant) * (count + 1));
    for (size_t index = 0; index < count; index++) {
        converted[index].root = px_get_str(grants->as.array.items[index], "root");
        converted[index].access = px_get_str(grants->as.array.items[index], "access");
    }
    PxPathChecker checker;
    PxDecision decision;
    const char *code = NULL;
    bool ok = px_path_checker(arena, converted, count, &checker, &code);
    const char *need = px_get_str(input, "need");
    if (ok) {
        ok = px_path_check(arena, &checker, px_get_str(input, "target"),
            need == NULL ? "read" : need, &decision, &code);
    }
    if (!check((!ok) == px_get_bool(expect, "error", false), "policy error mismatch")) {
        return false;
    }
    return !ok || check(decision.allowed == px_get_bool(expect, "allowed", false),
        "policy allowed mismatch");
}

bool px_run_context(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *messages = px_obj_get(input, "messages");
    size_t count = messages == NULL ? 0 : messages->as.array.len;
    PxContextMessage *converted = px_arena_alloc(arena, sizeof(PxContextMessage) * (count + 1));
    for (size_t index = 0; index < count; index++) {
        PxValue *message = messages->as.array.items[index];
        if (px_obj_get(message, "toolId") != NULL
                || px_obj_get(message, "toolCalls") != NULL
                || px_obj_get(message, "contentBlocks") != NULL) {
            return check(false, "public context API cannot represent rich messages");
        }
        converted[index].role = px_get_str(message, "role");
        converted[index].content = px_get_str(message, "content");
        if (converted[index].content == NULL) {
            converted[index].content = "";
        }
    }
    const char *operation = px_get_str(input, "operation");
    if (operation != NULL && strcmp(operation, "estimate") == 0) {
        return check(px_estimate_tokens(converted, count) == (int)px_get_num(expect, "tokens", 0),
            "context tokens mismatch");
    }
    PxValue *budget = px_obj_get(input, "budget");
    PxContextBudget config = {(int)px_get_num(budget, "maxTokens", 0),
        (int)px_get_num(budget, "keepRecent", 0)};
    PxContextMessage *out = NULL;
    size_t out_count = 0;
    bool ok = px_compact_context(arena, &config, converted, count, &out, &out_count);
    if (!check(ok == px_get_bool(expect, "ok", false), "context ok mismatch")) {
        return false;
    }
    if (!ok) {
        return true;
    }
    PxValue *wire = px_arr(arena);
    for (size_t index = 0; index < out_count; index++) {
        px_arr_push(arena, wire, px_message_wire(arena, &out[index]));
    }
    return check(px_equals(wire, px_obj_get(expect, "messages")), "context messages mismatch")
        && check(px_estimate_tokens(out, out_count) == (int)px_get_num(expect, "tokens", 0),
            "context compacted tokens mismatch");
}
