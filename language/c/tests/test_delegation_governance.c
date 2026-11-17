#include "delegation.h"
#include "praxo_core.h"

#include <assert.h>
#include <string.h>

#define MAX_TOOLS 4
#define MAX_EFFECTS 8

typedef struct {
    const char *name;
    const char *argument;
} Effect;

typedef struct {
    Effect items[MAX_EFFECTS];
    int count;
} EffectLog;

typedef struct {
    const char *allowed[MAX_TOOLS];
    size_t count;
} ToolScope;

typedef struct {
    const char *tool_name;
    const char *arguments_json;
    const char *mutate_key;
    const char *mutate_to;
    const char *deny_key;
    const char *deny_value;
    const ToolScope *scope;
    int *budget;
    EffectLog *effects;
    int *cancel_source;
    int cancel_after_generate;
    int generate_calls;
    int invoke_calls;
    int policy_calls;
} ChildState;

typedef struct GovNode {
    ToolScope delegable;
    int depth;
    int max_depth;
    int active_children;
    int max_children;
    int budget_remaining;
    int cancelled;
} GovNode;

typedef const char *(*ChildRun)(PxArena *arena, void *ctx,
    PxAgentResult *result);

typedef struct {
    ChildRun run;
    void *ctx;
    PxAgentResult *result;
} DelegateCtx;

static ToolScope scope_of(const char *first, const char *second) {
    ToolScope scope;
    memset(&scope, 0, sizeof(scope));
    if (first != NULL) {
        scope.allowed[scope.count++] = first;
    }
    if (second != NULL) {
        scope.allowed[scope.count++] = second;
    }
    return scope;
}

static GovNode gov_node(ToolScope delegable, int max_depth, int max_children,
        int budget) {
    GovNode node;
    memset(&node, 0, sizeof(node));
    node.delegable = delegable;
    node.max_depth = max_depth;
    node.max_children = max_children;
    node.budget_remaining = budget;
    return node;
}

static ChildState child_state(const char *tool, const char *arguments,
        const ToolScope *scope, EffectLog *effects) {
    ChildState state;
    memset(&state, 0, sizeof(state));
    state.tool_name = tool;
    state.arguments_json = arguments;
    state.scope = scope;
    state.effects = effects;
    return state;
}

static int scope_has(const ToolScope *scope, const char *name) {
    for (size_t index = 0; index < scope->count; index++) {
        if (strcmp(scope->allowed[index], name) == 0) {
            return 1;
        }
    }
    return 0;
}

static PxValue *scripted_generate(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)messages;
    (void)tools;
    ChildState *state = ctx;
    state->generate_calls++;
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content",
        px_str(arena, state->generate_calls == 1 ? "" : "done"));
    if (state->generate_calls == 1) {
        PxValue *calls = px_arr(arena);
        PxValue *call = px_obj(arena);
        px_obj_set(arena, call, "id", px_str(arena, "call-1"));
        px_obj_set(arena, call, "name",
            px_str(arena, state->tool_name == NULL ? "read" : state->tool_name));
        PxValue *arguments = px_parse(arena,
            state->arguments_json == NULL ? "{}" : state->arguments_json);
        px_obj_set(arena, call, "arguments", arguments);
        px_arr_push(arena, calls, call);
        px_obj_set(arena, response, "toolCalls", calls);
    }
    return response;
}

static PxValue *effect_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    ChildState *state = ctx;
    state->invoke_calls++;
    if (state->budget != NULL) {
        if (*state->budget <= 0) {
            return px_str(arena, "BUDGET_EXHAUSTED");
        }
        (*state->budget)--;
    }
    if (state->effects != NULL && state->effects->count < MAX_EFFECTS) {
        Effect *effect = &state->effects->items[state->effects->count];
        effect->name = name;
        effect->argument = px_get_str(arguments,
            state->deny_key == NULL ? "target" : state->deny_key);
        state->effects->count++;
    }
    return px_str(arena, "ok");
}

static const char *effect_authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)tool_name;
    ChildState *state = ctx;
    if (strcmp(kind, "tool.invoke") != 0) {
        return NULL;
    }
    state->policy_calls++;
    if (state->deny_key != NULL && state->deny_value != NULL) {
        const char *value = px_get_str(arguments, state->deny_key);
        if (value != NULL && strcmp(value, state->deny_value) == 0) {
            return "AGENT_POLICY_DENIED";
        }
    }
    return NULL;
}

static int child_cancelled(void *ctx) {
    ChildState *state = ctx;
    if (state->cancel_source != NULL && *state->cancel_source) {
        return 1;
    }
    if (state->cancel_after_generate && state->generate_calls > 0) {
        return 1;
    }
    return 0;
}

static PxValue *mutate_arguments(PxArena *arena, const char **name,
        PxValue *arguments, void *ctx) {
    (void)name;
    (void)arguments;
    ChildState *state = ctx;
    if (state->mutate_key == NULL) {
        return arguments;
    }
    PxValue *next = px_obj(arena);
    px_obj_set(arena, next, state->mutate_key,
        px_str(arena, state->mutate_to == NULL ? "" : state->mutate_to));
    return next;
}

static const char *agent_child(PxArena *arena, ChildState *state,
        PxAgentResult *result) {
    PxAgentOptions options;
    memset(&options, 0, sizeof(options));
    PxAgentMiddleware middleware;
    memset(&middleware, 0, sizeof(middleware));
    middleware.before_tool = mutate_arguments;
    middleware.ctx = state;
    options.generate = scripted_generate;
    options.invoke = effect_invoke;
    options.authorize = effect_authorize;
    options.middleware = &middleware;
    options.middleware_count = state->mutate_key == NULL ? 0 : 1;
    options.allowed_tools = (const char *const *)state->scope->allowed;
    options.allowed_tools_count = state->scope->count;
    options.cancelled = child_cancelled;
    options.require_policy = true;
    options.require_tool_scope = true;
    options.ctx = state;
    options.max_steps = 2;
    return px_agent_run(arena, &options, NULL, "go", result);
}

static const char *run_child(PxArena *arena, void *ctx, PxAgentResult *result) {
    ChildState *state = ctx;
    return agent_child(arena, state, result);
}

static bool delegate_runner(PxArena *arena, const PxSubagentRequest *request,
        void *ctx, PxSubagentResult *result, const char **error) {
    (void)request;
    DelegateCtx *delegate = ctx;
    const char *run_error = delegate->run(arena, delegate->ctx,
        delegate->result);
    if (run_error != NULL) {
        if (error != NULL) {
            *error = run_error;
        }
        return false;
    }
    result->output = delegate->result->output;
    return true;
}

static const char *gov_delegate(PxArena *arena, GovNode *parent,
        const ToolScope *child_scope, ChildRun run, void *ctx,
        PxAgentResult *result) {
    if (parent->depth + 1 > parent->max_depth) {
        return "DELEGATION_DEPTH_EXCEEDED";
    }
    if (parent->active_children >= parent->max_children) {
        return "DELEGATION_CHILDREN_EXCEEDED";
    }
    for (size_t index = 0; index < child_scope->count; index++) {
        if (!scope_has(&parent->delegable, child_scope->allowed[index])) {
            return "DELEGATION_SCOPE_EXCEEDED";
        }
    }
    if (parent->budget_remaining <= 0) {
        return "DELEGATION_BUDGET_EXHAUSTED";
    }
    parent->active_children++;
    DelegateCtx delegate;
    delegate.run = run;
    delegate.ctx = ctx;
    delegate.result = result;
    PxSubagentRequest request = px_subagent_request("parent", "child", "go");
    const char *error = NULL;
    PxSubagentTask *task = px_subagent_run(arena, delegate_runner, &delegate,
        &request, &error);
    parent->active_children--;
    if (task == NULL) {
        return error == NULL ? "SUBAGENT_INVALID" : error;
    }
    if (strcmp(task->status, "completed") != 0) {
        return task->error[0] == '\0' ? "SUBAGENT_FAILED" : task->error;
    }
    return NULL;
}

static void test_tool_scope(void) {
    PxArena arena;
    px_arena_init(&arena);
    EffectLog effects;
    memset(&effects, 0, sizeof(effects));
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 2, 2, 2);
    PxAgentResult result;

    ToolScope wide = scope_of("read", "write");
    ChildState blocked = child_state("write", "{\"target\":\"safe\"}", &wide,
        &effects);
    const char *error = gov_delegate(&arena, &parent, &wide, run_child,
        &blocked, &result);
    assert(strcmp(error, "DELEGATION_SCOPE_EXCEEDED") == 0);
    assert(blocked.generate_calls == 0);
    assert(blocked.invoke_calls == 0);
    assert(effects.count == 0);

    ToolScope narrow = scope_of("read", NULL);
    ChildState allowed = child_state("read", "{\"target\":\"safe\"}", &narrow,
        &effects);
    error = gov_delegate(&arena, &parent, &narrow, run_child, &allowed, &result);
    assert(error == NULL);
    assert(effects.count == 1);
    assert(strcmp(effects.items[0].name, "read") == 0);

    px_arena_free(&arena);
}

typedef struct {
    GovNode *child_node;
    ToolScope scope;
    const char *nested_error;
    int child_invoked;
    int grandchild_invoked;
} DepthCtx;

static const char *depth_grandchild_run(PxArena *arena, void *ctx,
        PxAgentResult *result) {
    (void)arena;
    (void)result;
    DepthCtx *depth = ctx;
    depth->grandchild_invoked++;
    return NULL;
}

static const char *depth_child_run(PxArena *arena, void *ctx,
        PxAgentResult *result) {
    DepthCtx *depth = ctx;
    depth->child_invoked++;
    depth->nested_error = gov_delegate(arena, depth->child_node,
        &depth->scope, depth_grandchild_run, depth, result);
    return NULL;
}

static void test_depth_limit(void) {
    PxArena arena;
    px_arena_init(&arena);
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 1, 2, 2);
    GovNode child_node = parent;
    child_node.depth = 1;
    DepthCtx depth;
    memset(&depth, 0, sizeof(depth));
    depth.child_node = &child_node;
    depth.scope = scope_of("read", NULL);
    PxAgentResult result;
    const char *error = gov_delegate(&arena, &parent, &depth.scope,
        depth_child_run, &depth, &result);
    assert(error == NULL);
    assert(depth.child_invoked == 1);
    assert(depth.nested_error != NULL);
    assert(strcmp(depth.nested_error, "DELEGATION_DEPTH_EXCEEDED") == 0);
    assert(depth.grandchild_invoked == 0);
    px_arena_free(&arena);
}

typedef struct {
    GovNode *parent;
    ToolScope scope;
    const char *nested_error;
    int attempts;
    int inner_invoked;
} CountCtx;

static const char *count_inner_run(PxArena *arena, void *ctx,
        PxAgentResult *result) {
    (void)arena;
    (void)result;
    CountCtx *count = ctx;
    count->inner_invoked++;
    return NULL;
}

static const char *count_outer_run(PxArena *arena, void *ctx,
        PxAgentResult *result) {
    CountCtx *count = ctx;
    count->attempts++;
    count->nested_error = gov_delegate(arena, count->parent, &count->scope,
        count_inner_run, count, result);
    return NULL;
}

static void test_child_count(void) {
    PxArena arena;
    px_arena_init(&arena);
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 2, 1, 2);
    CountCtx count;
    memset(&count, 0, sizeof(count));
    count.parent = &parent;
    count.scope = scope_of("read", NULL);
    PxAgentResult result;
    const char *error = gov_delegate(&arena, &parent, &count.scope,
        count_outer_run, &count, &result);
    assert(error == NULL);
    assert(count.attempts == 1);
    assert(count.nested_error != NULL);
    assert(strcmp(count.nested_error, "DELEGATION_CHILDREN_EXCEEDED") == 0);
    assert(count.inner_invoked == 0);
    assert(parent.active_children == 0);
    error = gov_delegate(&arena, &parent, &count.scope, count_outer_run,
        &count, &result);
    assert(error == NULL);
    assert(count.attempts == 2);
    assert(count.inner_invoked == 0);
    assert(parent.active_children == 0);
    px_arena_free(&arena);
}

static void test_sibling_budget(void) {
    PxArena arena;
    px_arena_init(&arena);
    EffectLog effects;
    memset(&effects, 0, sizeof(effects));
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 2, 2, 1);
    ToolScope scope = scope_of("read", NULL);
    PxAgentResult result;
    ChildState first = child_state("read", "{\"target\":\"safe\"}", &scope,
        &effects);
    first.budget = &parent.budget_remaining;
    const char *error = gov_delegate(&arena, &parent, &scope, run_child,
        &first, &result);
    assert(error == NULL);
    assert(effects.count == 1);
    assert(parent.budget_remaining == 0);
    ChildState second = child_state("read", "{\"target\":\"safe\"}", &scope,
        &effects);
    second.budget = &parent.budget_remaining;
    error = gov_delegate(&arena, &parent, &scope, run_child, &second, &result);
    assert(strcmp(error, "DELEGATION_BUDGET_EXHAUSTED") == 0);
    assert(second.generate_calls == 0);
    assert(second.invoke_calls == 0);
    assert(effects.count == 1);
    px_arena_free(&arena);
}

static void test_cancellation(void) {
    PxArena arena;
    px_arena_init(&arena);
    EffectLog effects;
    memset(&effects, 0, sizeof(effects));
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 2, 2, 2);
    parent.cancelled = 1;
    ToolScope scope = scope_of("read", NULL);
    PxAgentResult result;
    ChildState cancelled = child_state("read", "{\"target\":\"safe\"}",
        &scope, &effects);
    cancelled.cancel_source = &parent.cancelled;
    const char *error = gov_delegate(&arena, &parent, &scope, run_child,
        &cancelled, &result);
    assert(strcmp(error, "AGENT_CANCELLED") == 0);
    assert(cancelled.generate_calls == 0);
    assert(cancelled.invoke_calls == 0);
    assert(effects.count == 0);
    parent.cancelled = 0;
    ChildState late = child_state("read", "{\"target\":\"safe\"}", &scope,
        &effects);
    late.cancel_after_generate = 1;
    error = gov_delegate(&arena, &parent, &scope, run_child, &late, &result);
    assert(strcmp(error, "AGENT_CANCELLED") == 0);
    assert(late.generate_calls == 1);
    assert(late.invoke_calls == 0);
    assert(effects.count == 0);
    px_arena_free(&arena);
}

static void test_final_arguments(void) {
    PxArena arena;
    px_arena_init(&arena);
    EffectLog effects;
    memset(&effects, 0, sizeof(effects));
    ToolScope delegable = scope_of("read", NULL);
    GovNode parent = gov_node(delegable, 2, 2, 2);
    ToolScope scope = scope_of("read", NULL);
    ChildState child = child_state("read", "{\"target\":\"safe\"}", &scope,
        &effects);
    child.mutate_key = "target";
    child.mutate_to = "secret";
    child.deny_key = "target";
    child.deny_value = "secret";
    PxAgentResult result;
    const char *error = gov_delegate(&arena, &parent, &scope, run_child,
        &child, &result);
    assert(strcmp(error, "AGENT_POLICY_DENIED") == 0);
    assert(child.generate_calls == 1);
    assert(child.invoke_calls == 0);
    assert(child.policy_calls >= 2);
    assert(effects.count == 0);
    px_arena_free(&arena);
}

int main(void) {
    test_tool_scope();
    test_depth_limit();
    test_child_count();
    test_sibling_budget();
    test_cancellation();
    test_final_arguments();
    return 0;
}
