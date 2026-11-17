#include "harmovela.h"
#include "mcp.h"
#include "otel.h"
#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

#define MAX_EVENT_KINDS 32
#define MAX_EVENT_KIND 48

typedef struct {
    int parent;
    int child;
    int blocked;
    int tool_calls;
} McpState;

typedef struct {
    int otel_count;
    int harmovela_count;
    char otel[MAX_EVENT_KINDS][MAX_EVENT_KIND];
    char harmovela[MAX_EVENT_KINDS][MAX_EVENT_KIND];
} EventLog;

typedef struct {
    McpState mcp;
    PxMcpClient client;
    PxOtelSink otel;
    PxHarmovelaSink harmovela;
    EventLog log;
    int parent_calls;
    int child_calls;
} Chain;

typedef struct {
    McpState mcp;
    PxMcpClient client;
    int model_calls;
    int invoke_calls;
} Denial;

static void record_kind(char (*kinds)[MAX_EVENT_KIND], int *count,
        const char *kind) {
    if (kind == NULL || *count >= MAX_EVENT_KINDS) {
        return;
    }
    snprintf(kinds[*count], MAX_EVENT_KIND, "%s", kind);
    (*count)++;
}

static int has_kind(char (*kinds)[MAX_EVENT_KIND], int count,
        const char *kind) {
    for (int index = 0; index < count; index++) {
        if (strcmp(kinds[index], kind) == 0) {
            return 1;
        }
    }
    return 0;
}

static const char *otel_span_name(PxValue *payload) {
    PxValue *resources = px_obj_get(payload, "resourceSpans");
    if (resources == NULL || resources->type != PX_ARR
            || resources->as.array.len == 0) {
        return NULL;
    }
    PxValue *scopes = px_obj_get(resources->as.array.items[0], "scopeSpans");
    if (scopes == NULL || scopes->type != PX_ARR
            || scopes->as.array.len == 0) {
        return NULL;
    }
    PxValue *spans = px_obj_get(scopes->as.array.items[0], "spans");
    if (spans == NULL || spans->type != PX_ARR
            || spans->as.array.len == 0) {
        return NULL;
    }
    return px_get_str(spans->as.array.items[0], "name");
}

static bool otel_transport(const char *method, const char *url,
        const char *content_type, const char *body, void *ctx,
        PxOtelResponse *response, const char **error) {
    EventLog *log = ctx;
    (void)url;
    (void)content_type;
    if (error != NULL) {
        *error = NULL;
    }
    if (strcmp(method, "POST") != 0) {
        if (error != NULL) {
            *error = "OTEL_METHOD";
        }
        return false;
    }
    PxArena arena;
    px_arena_init(&arena);
    PxValue *payload = px_parse(&arena, body);
    record_kind(log->otel, &log->otel_count, otel_span_name(payload));
    px_arena_free(&arena);
    response->status = 200;
    response->body = "";
    return true;
}

static bool harmovela_transport(const char *method, const char *url,
        const char *content_type, const char *body, void *ctx,
        PxHarmovelaResponse *response, const char **error) {
    EventLog *log = ctx;
    (void)url;
    (void)content_type;
    if (error != NULL) {
        *error = NULL;
    }
    if (strcmp(method, "POST") != 0) {
        if (error != NULL) {
            *error = "HARMOVELA_METHOD";
        }
        return false;
    }
    PxArena arena;
    px_arena_init(&arena);
    PxValue *payload = px_parse(&arena, body);
    record_kind(log->harmovela, &log->harmovela_count,
        px_get_str(payload, "type"));
    px_arena_free(&arena);
    response->status = 202;
    response->body = "";
    return true;
}

static long long fixed_clock(void *ctx) {
    (void)ctx;
    return 1794294000000000000LL;
}

static PxValue *fake_mcp(PxArena *arena, const char *method, PxValue *params,
        void *ctx, const char **error) {
    McpState *state = ctx;
    if (error != NULL) {
        *error = NULL;
    }
    if (strcmp(method, "initialize") == 0) {
        return px_parse(arena,
            "{\"protocolVersion\":\"2024-11-05\","
            "\"capabilities\":{\"tools\":{}},"
            "\"serverInfo\":{\"name\":\"fake-mcp\",\"version\":\"0.0.1\"}}");
    }
    if (strcmp(method, "tools/list") == 0) {
        return px_parse(arena,
            "{\"tools\":[{\"name\":\"record\",\"description\":\"Record\","
            "\"inputSchema\":{\"type\":\"object\","
            "\"properties\":{\"target\":{\"type\":\"string\"}},"
            "\"required\":[\"target\"]}}]}");
    }
    if (strcmp(method, "tools/call") == 0) {
        const char *name = px_get_str(params, "name");
        if (name == NULL || strcmp(name, "record") != 0) {
            return px_parse(arena, "{\"isError\":true}");
        }
        const char *target = px_get_str(px_obj_get(params, "arguments"),
            "target");
        state->tool_calls++;
        if (target != NULL && strcmp(target, "parent") == 0) {
            state->parent++;
        } else if (target != NULL && strcmp(target, "child") == 0) {
            state->child++;
        } else if (target != NULL && strcmp(target, "blocked") == 0) {
            state->blocked++;
        }
        return px_parse(arena,
            "{\"content\":[{\"type\":\"text\",\"text\":\"recorded\"}]}");
    }
    if (error != NULL) {
        *error = "MCP_RPC";
    }
    return NULL;
}

static void chain_emit(const char *kind, void *ctx) {
    Chain *chain = ctx;
    PxArena arena;
    px_arena_init(&arena);
    PxEvent event;
    event.kind = kind;
    event.session_id = "chain";
    event.run_id = "chain-run";
    event.data = NULL;
    const char *error = NULL;
    (void)px_otel_emit(&arena, &chain->otel, &event, &error);
    (void)px_harmovela_emit(&arena, &chain->harmovela, &event, &error);
    px_arena_free(&arena);
}

static PxValue *parent_generate(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)messages;
    (void)tools;
    Chain *chain = ctx;
    chain->parent_calls++;
    PxValue *response = px_obj(arena);
    if (chain->parent_calls == 1 || chain->parent_calls == 2) {
        PxValue *call = px_obj(arena);
        PxValue *arguments = px_obj(arena);
        if (chain->parent_calls == 1) {
            px_obj_set(arena, call, "id", px_str(arena, "parent-record"));
            px_obj_set(arena, call, "name", px_str(arena, "record"));
            px_obj_set(arena, arguments, "target", px_str(arena, "parent"));
        } else {
            px_obj_set(arena, call, "id", px_str(arena, "parent-delegate"));
            px_obj_set(arena, call, "name", px_str(arena, "delegate"));
            px_obj_set(arena, arguments, "task", px_str(arena, "child"));
        }
        px_obj_set(arena, call, "arguments", arguments);
        PxValue *calls = px_arr(arena);
        px_arr_push(arena, calls, call);
        px_obj_set(arena, response, "toolCalls", calls);
    } else {
        px_obj_set(arena, response, "content", px_str(arena, "DONE"));
    }
    return response;
}

static PxValue *child_generate(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)messages;
    (void)tools;
    Chain *chain = ctx;
    chain->child_calls++;
    PxValue *response = px_obj(arena);
    if (chain->child_calls == 1) {
        PxValue *call = px_obj(arena);
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, call, "id", px_str(arena, "child-record"));
        px_obj_set(arena, call, "name", px_str(arena, "record"));
        px_obj_set(arena, arguments, "target", px_str(arena, "child"));
        px_obj_set(arena, call, "arguments", arguments);
        PxValue *calls = px_arr(arena);
        px_arr_push(arena, calls, call);
        px_obj_set(arena, response, "toolCalls", calls);
    } else {
        px_obj_set(arena, response, "content", px_str(arena, "CHILD-DONE"));
    }
    return response;
}

static const char *parent_authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)ctx;
    if (strcmp(kind, "model.generate") == 0) {
        return NULL;
    }
    if (strcmp(kind, "tool.invoke") != 0) {
        return "AGENT_POLICY_DENIED";
    }
    if (strcmp(tool_name, "record") == 0) {
        const char *target = px_get_str(arguments, "target");
        if (target != NULL && strcmp(target, "blocked") == 0) {
            return "AGENT_POLICY_DENIED";
        }
        return NULL;
    }
    if (strcmp(tool_name, "delegate") == 0) {
        return NULL;
    }
    return "AGENT_POLICY_DENIED";
}

static const char *child_authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    const char *denied = parent_authorize(kind, session_id, tool_name,
        arguments, ctx);
    if (denied != NULL) {
        return denied;
    }
    if (strcmp(kind, "model.generate") == 0) {
        return NULL;
    }
    if (strcmp(kind, "tool.invoke") == 0
            && strcmp(tool_name, "record") == 0) {
        return NULL;
    }
    return "AGENT_POLICY_DENIED";
}

static PxValue *child_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    Chain *chain = ctx;
    const char *error = NULL;
    PxValue *value = px_mcp_call_tool(arena, &chain->client, name, arguments,
        &error);
    if (value == NULL) {
        return px_str(arena, error == NULL ? "MCP_ERROR" : error);
    }
    return value;
}

static PxValue *run_child(PxArena *arena, Chain *chain) {
    static const char *allowed[] = {"record"};
    PxAgentOptions options;
    memset(&options, 0, sizeof(options));
    options.generate = child_generate;
    options.invoke = child_invoke;
    options.authorize = child_authorize;
    options.emit = chain_emit;
    options.ctx = chain;
    options.max_steps = 3;
    options.allowed_tools = (const char *const *)allowed;
    options.allowed_tools_count = 1;
    options.require_policy = true;
    options.require_tool_scope = true;
    PxAgentResult result;
    const char *error = px_agent_run(arena, &options, NULL, "record child",
        &result);
    PxValue *output = px_obj(arena);
    if (error != NULL) {
        px_obj_set(arena, output, "error", px_str(arena, error));
        return output;
    }
    px_obj_set(arena, output, "output", px_str(arena, result.output));
    px_obj_set(arena, output, "child", px_num(arena, chain->mcp.child));
    return output;
}

static PxValue *parent_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    Chain *chain = ctx;
    if (strcmp(name, "record") == 0) {
        return child_invoke(arena, name, arguments, ctx);
    }
    if (strcmp(name, "delegate") == 0) {
        return run_child(arena, chain);
    }
    return px_str(arena, "unknown tool");
}

static PxValue *denial_generate(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)messages;
    (void)tools;
    Denial *denial = ctx;
    denial->model_calls++;
    PxValue *response = px_obj(arena);
    if (denial->model_calls == 1) {
        PxValue *call = px_obj(arena);
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, call, "id", px_str(arena, "denied-record"));
        px_obj_set(arena, call, "name", px_str(arena, "record"));
        px_obj_set(arena, arguments, "target", px_str(arena, "safe"));
        px_obj_set(arena, call, "arguments", arguments);
        PxValue *calls = px_arr(arena);
        px_arr_push(arena, calls, call);
        px_obj_set(arena, response, "toolCalls", calls);
    } else {
        px_obj_set(arena, response, "content", px_str(arena, "UNEXPECTED"));
    }
    return response;
}

static PxValue *denial_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)name;
    (void)arguments;
    Denial *denial = ctx;
    denial->invoke_calls++;
    return px_str(arena, "unexpected invoke");
}

static PxValue *edit_target(PxArena *arena, const char **name,
        PxValue *arguments, void *ctx) {
    (void)name;
    (void)arguments;
    (void)ctx;
    PxValue *next = px_obj(arena);
    px_obj_set(arena, next, "target", px_str(arena, "blocked"));
    return next;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    Chain chain;
    memset(&chain, 0, sizeof(chain));
    chain.otel = px_otel_sink("http://otel.test/v1/traces", "praxo-chain",
        otel_transport, &chain.log);
    chain.harmovela = px_harmovela_sink("http://harmovela.test", "praxo-chain",
        "0.2", harmovela_transport, &chain.log);
    chain.harmovela.clock = fixed_clock;

    const char *error = NULL;
    assert(px_mcp_client(&arena, fake_mcp, &chain.mcp, "", "", &chain.client,
        &error));
    PxValue *tools = px_mcp_list_tools(&arena, &chain.client, &error);
    assert(tools != NULL && tools->type == PX_ARR && tools->as.array.len == 1);

    static const char *parent_tools[] = {"record", "delegate"};
    PxAgentOptions options;
    memset(&options, 0, sizeof(options));
    options.generate = parent_generate;
    options.invoke = parent_invoke;
    options.authorize = parent_authorize;
    options.emit = chain_emit;
    options.ctx = &chain;
    options.max_steps = 6;
    options.allowed_tools = (const char *const *)parent_tools;
    options.allowed_tools_count = 2;
    options.require_policy = true;
    options.require_tool_scope = true;

    PxAgentResult result;
    error = px_agent_run(&arena, &options, NULL, "run the chain", &result);
    assert(error == NULL);
    assert(result.output != NULL && strcmp(result.output, "DONE") == 0);
    assert(chain.mcp.parent == 1);
    assert(chain.mcp.child == 1);
    assert(chain.mcp.tool_calls == 2);
    assert(chain.child_calls >= 2);
    assert(has_kind(chain.log.otel, chain.log.otel_count,
        "praxo.run.started"));
    assert(has_kind(chain.log.otel, chain.log.otel_count, "praxo.tool.call"));
    assert(has_kind(chain.log.otel, chain.log.otel_count,
        "praxo.run.completed"));
    assert(has_kind(chain.log.harmovela, chain.log.harmovela_count,
        "run.started"));
    assert(has_kind(chain.log.harmovela, chain.log.harmovela_count,
        "tool.call"));
    assert(has_kind(chain.log.harmovela, chain.log.harmovela_count,
        "run.completed"));
    px_mcp_close(&chain.client);

    Denial denial;
    memset(&denial, 0, sizeof(denial));
    assert(px_mcp_client(&arena, fake_mcp, &denial.mcp, "", "", &denial.client,
        &error));
    PxAgentMiddleware middleware;
    memset(&middleware, 0, sizeof(middleware));
    middleware.before_tool = edit_target;
    PxAgentOptions denial_options;
    memset(&denial_options, 0, sizeof(denial_options));
    denial_options.generate = denial_generate;
    denial_options.invoke = denial_invoke;
    denial_options.authorize = parent_authorize;
    denial_options.ctx = &denial;
    denial_options.middleware = &middleware;
    denial_options.middleware_count = 1;
    denial_options.max_steps = 2;
    static const char *denial_tools[] = {"record"};
    denial_options.allowed_tools = (const char *const *)denial_tools;
    denial_options.allowed_tools_count = 1;
    denial_options.require_policy = true;
    denial_options.require_tool_scope = true;

    PxAgentResult denial_result;
    error = px_agent_run(&arena, &denial_options, NULL, "call record",
        &denial_result);
    assert(error != NULL);
    assert(strcmp(error, "AGENT_POLICY_DENIED") == 0);
    assert(denial.invoke_calls == 0);
    assert(denial.mcp.blocked == 0);
    assert(denial.mcp.tool_calls == 0);
    px_mcp_close(&denial.client);

    printf("output: %s\n", result.output);
    printf("effects parent=1 child=1 tool_calls=%d\n", chain.mcp.tool_calls);
    printf("child calls: %d\n", chain.child_calls);
    printf("otel spans: %d\n", chain.log.otel_count);
    printf("harmovela events: %d\n", chain.log.harmovela_count);
    printf("denied effect: %d\n", denial.mcp.blocked);

    px_arena_free(&arena);
    return 0;
}
