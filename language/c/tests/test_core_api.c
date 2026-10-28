#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static PxValue *static_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)messages;
    (void)tools;
    (void)ctx;
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, "ok"));
    return response;
}

static char *repair(PxArena *arena, const char *text, void *ctx) {
    (void)text;
    (void)ctx;
    return px_arena_strdup(arena, "{\"name\":\"fixed\"}");
}

static PxValue *history_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)tools;
    int *step = ctx;
    if ((*step)++ == 0) {
        assert(messages->as.array.len == 2);
        assert(strcmp(px_get_str(messages->as.array.items[0], "content"), "prior") == 0);
        return px_parse(arena, "{\"toolCalls\":[{\"id\":\"call-1\",\"name\":\"echo\",\"arguments\":{\"text\":\"hi\"}}]}");
    }
    PxValue *wire = px_parse(arena, px_stringify(arena, messages));
    assert(wire != NULL && wire->as.array.len == 4);
    PxValue *tool = wire->as.array.items[3];
    assert(strcmp(px_get_str(tool, "role"), "tool") == 0);
    const char *id = px_get_str(tool, "toolId");
    assert(id != NULL && strcmp(id, "call-1") == 0);
    assert(px_obj_get(tool, "toolCallId") == NULL);
    assert(px_equals(px_parse(arena, px_get_str(tool, "content")),
        px_parse(arena, "{\"text\":\"hi\"}")));
    return px_parse(arena, "{\"content\":\"done\"}");
}

static PxValue *history_tool(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arena;
    (void)ctx;
    assert(strcmp(name, "echo") == 0);
    return arguments;
}

typedef struct {
    int generate_calls;
    int invoke_calls;
    int event_count;
    const char *events[32];
    double input_tokens;
    double output_tokens;
    bool tool_loop;
    bool request_cancel_on_start;
    bool cancel_requested;
} AgentBoundary;

static PxValue *boundary_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)messages;
    (void)tools;
    AgentBoundary *state = ctx;
    state->generate_calls++;
    PxValue *response = px_obj(arena);
    px_obj_set(arena, response, "content", px_str(arena, "ok"));
    px_obj_set(arena, response, "inputTokens", px_num(arena, state->input_tokens));
    px_obj_set(arena, response, "outputTokens", px_num(arena, state->output_tokens));
    if (state->tool_loop) {
        PxValue *calls = px_arr(arena);
        PxValue *call = px_obj(arena);
        PxValue *arguments = px_obj(arena);
        px_obj_set(arena, arguments, "step", px_num(arena, state->generate_calls));
        px_obj_set(arena, call, "id", px_str(arena, "call-1"));
        px_obj_set(arena, call, "name", px_str(arena, "echo"));
        px_obj_set(arena, call, "arguments", arguments);
        px_arr_push(arena, calls, call);
        px_obj_set(arena, response, "toolCalls", calls);
    }
    return response;
}

static PxValue *boundary_invoke(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arena;
    (void)name;
    AgentBoundary *state = ctx;
    state->invoke_calls++;
    return arguments;
}

static void boundary_emit(const char *kind, void *ctx) {
    AgentBoundary *state = ctx;
    if (state->event_count < 32) {
        state->events[state->event_count] = kind;
    }
    state->event_count++;
    if (state->request_cancel_on_start && strcmp(kind, "run.started") == 0) {
        state->cancel_requested = true;
    }
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxMemoryStore store;
    px_memory_init(&store);
    PxMemoryRecord record;
    assert(px_memory_put(&arena, &store, "s1", "m1", "event", "Alpha", "2026-01-01", &record));
    assert(px_memory_put(&arena, &store, "s1", "m2", "event", "beta", "2026-01-02", &record));
    PxMemoryRecord *matches = NULL;
    assert(px_memory_search(&arena, &store, "s1", "alpha", 10, &matches) == 1);
    assert(strcmp(matches[0].id, "m1") == 0);

    PxSink *sink = px_sink_new(&arena);
    PxEvent event = {"run.started", "s1", NULL, px_null(&arena)};
    px_sink_emit(sink, &event);
    const char **kinds = NULL;
    assert(px_sink_kinds(sink, &kinds) == 1 && strcmp(kinds[0], "run.started") == 0);

    const char *empty_predicate[] = {NULL};
    PxSink *empty_filter = px_sink_filter(&arena, px_sink_new(&arena), empty_predicate, 0);
    px_sink_emit(empty_filter, &event);
    assert(px_sink_kinds(empty_filter, &kinds) == 0);
    PxSink *nil_filter = px_sink_filter(&arena, px_sink_new(&arena), NULL, 0);
    px_sink_emit(nil_filter, &event);
    assert(px_sink_kinds(nil_filter, &kinds) == 1);

    PxAllowlist allow;
    px_checkpoint_init(&allow);
    assert(px_checkpoint_register(&arena, &allow, "spec.payload"));
    PxValue *value = px_parse(&arena, "{\"x\":1}");
    char *data = NULL;
    assert(px_checkpoint_marshal(&arena, &allow, "spec.payload", value, &data) == NULL);
    PxValue *decoded = NULL;
    assert(px_checkpoint_unmarshal(&arena, &allow, data, &decoded) == NULL);
    assert(px_equals(decoded, value));
    assert(strcmp(px_checkpoint_marshal(&arena, &allow, "missing", value, &data),
        "CHECKPOINT_TYPE_NOT_ALLOWED") == 0);
    assert(strcmp(px_checkpoint_unmarshal(&arena, &allow,
        "{\"type\":\"missing\",\"data\":{\"x\":1}}", &decoded),
        "CHECKPOINT_TYPE_NOT_ALLOWED") == 0);
    assert(strcmp(px_checkpoint_unmarshal(&arena, &allow, "not json", &decoded),
        "CHECKPOINT_ERROR") == 0);

    PxPathGrant grants[] = {{"allowed", "read"}};
    PxPathChecker checker;
    const char *code = "x";
    assert(px_path_checker(&arena, grants, 1, &checker, &code) && code == NULL);
    assert(px_path_allowed(&arena, &checker, "allowed/sub/file", "read"));
    assert(!px_path_allowed(&arena, &checker, "../allowed/file", "read"));

    PxContextMessage messages[] = {
        {"system", "sys"},
        {"user", "message 0"},
        {"user", "message 1"}
    };
    assert(px_estimate_tokens(messages, 3) == 16);
    PxContextBudget budget = {0, 0};
    PxContextMessage *compacted = NULL;
    size_t compacted_count = 0;
    assert(px_compact_context(&arena, &budget, messages, 3, &compacted, &compacted_count));
    assert(compacted_count == 3);
    PxContextBudget impossible = {2, 0};
    assert(!px_compact_context(&arena, &impossible, messages, 3, &compacted, &compacted_count));
    PxValue *wire = px_message_wire(&arena, &messages[1]);
    assert(strcmp(px_get_str(wire, "role"), "user") == 0);

    char *redacted = px_pii_redact(&arena, "email a@b.com");
    assert(strcmp(redacted, "email [REDACTED:email]") == 0);

    PxValue *schema = px_parse(&arena, "{\"type\":\"object\",\"required\":[\"name\"]}");
    PxStructuredOutput structured = {schema, 1, repair, NULL};
    assert(strcmp(px_apply_structured(&arena, &structured, "bad"), "{\"name\":\"fixed\"}") == 0);
    structured.max_repairs = 0;
    assert(px_apply_structured(&arena, &structured, "bad") == NULL);

    PxCallLimit limit;
    px_call_limit_init(&limit, 1, 1);
    assert(px_call_limit_model(&limit) == NULL);
    assert(strcmp(px_call_limit_model(&limit), "AGENT_MODEL_CALL_LIMIT") == 0);
    assert(px_call_limit_tool(&limit) == NULL);
    assert(strcmp(px_call_limit_tool(&limit), "AGENT_TOOL_CALL_LIMIT") == 0);

    const char *selection[] = {"echo"};
    const char *tools[] = {"echo", "other"};
    const char **advertised = NULL;
    assert(px_select_tools(&arena, selection, 1, tools, 2, &advertised) == 1);
    assert(strcmp(advertised[0], "echo") == 0);
    assert(strcmp(px_check_tool_selected(selection, 1, "other"), "AGENT_TOOL_NOT_SELECTED") == 0);

    const char **stream = NULL;
    assert(px_stream_kinds(&stream) == 6 && strcmp(stream[0], "values") == 0);
    assert(strcmp(px_fallback("primary", "fallback", true), "fallback") == 0);
    assert(strcmp(px_fallback("primary", "fallback", false), "primary") == 0);

    PxAgentOptions options = {static_model, NULL, NULL, NULL, 2, 0};
    PxAgentResult result;
    assert(px_agent_run(&arena, &options, NULL, "hello", &result) == NULL);
    assert(result.steps == 1 && strcmp(result.output, "ok") == 0);

    int step = 0;
    PxAgentOptions history = {history_model, history_tool, NULL, &step, 2, 0};
    PxValue *session = px_parse(&arena, "[{\"role\":\"assistant\",\"content\":\"prior\"}]");
    assert(px_agent_run(&arena, &history, session, "hello", &result) == NULL);
    assert(step == 2 && result.steps == 2 && strcmp(result.output, "done") == 0);
    assert(session->as.array.len == 1);

    PxAgentResult boundary_result = {"x", 9, 9, 9};
    assert(strcmp(px_agent_run(&arena, NULL, NULL, "hello", &boundary_result),
        "AGENT_INVALID_OPTIONS") == 0);
    assert(boundary_result.steps == 0 && strcmp(boundary_result.output, "") == 0);
    assert(boundary_result.input_tokens == 0 && boundary_result.output_tokens == 0);

    AgentBoundary no_generate = {0};
    PxAgentOptions missing_generate = {NULL, NULL, boundary_emit, &no_generate, 2, 0};
    assert(strcmp(px_agent_run(&arena, &missing_generate, NULL, "hello",
        &boundary_result), "AGENT_INVALID_OPTIONS") == 0);
    assert(no_generate.event_count == 0);

    AgentBoundary uncancellable = {0};
    uncancellable.request_cancel_on_start = true;
    PxAgentOptions uncancellable_options = {boundary_model, boundary_invoke,
        boundary_emit, &uncancellable, 2, 0};
    assert(px_agent_run(&arena, &uncancellable_options, NULL, "hello",
        &boundary_result) == NULL);
    assert(uncancellable.cancel_requested);
    assert(uncancellable.generate_calls == 1 && uncancellable.invoke_calls == 0);
    assert(uncancellable.event_count == 2);
    assert(strcmp(uncancellable.events[0], "run.started") == 0);
    assert(strcmp(uncancellable.events[1], "run.completed") == 0);
    assert(boundary_result.steps == 1);

    AgentBoundary exact_step = {0};
    PxAgentOptions exact_step_options = {boundary_model, boundary_invoke,
        boundary_emit, &exact_step, 1, 0};
    assert(px_agent_run(&arena, &exact_step_options, NULL, "hello",
        &boundary_result) == NULL);
    assert(boundary_result.steps == 1 && exact_step.generate_calls == 1);
    assert(exact_step.event_count == 2);

    AgentBoundary one_step = {0};
    one_step.tool_loop = true;
    PxAgentOptions one_step_options = {boundary_model, boundary_invoke,
        boundary_emit, &one_step, 1, 0};
    assert(strcmp(px_agent_run(&arena, &one_step_options, NULL, "loop",
        &boundary_result), "AGENT_MAX_STEPS") == 0);
    assert(boundary_result.steps == 1);
    assert(one_step.generate_calls == 1 && one_step.invoke_calls == 1);
    assert(one_step.event_count == 3);
    assert(strcmp(one_step.events[0], "run.started") == 0);
    assert(strcmp(one_step.events[1], "tool.call") == 0);
    assert(strcmp(one_step.events[2], "run.failed") == 0);

    int step_defaults[] = {0, -1};
    for (size_t index = 0; index < 2; index++) {
        AgentBoundary loop = {0};
        loop.tool_loop = true;
        PxAgentOptions loop_options = {boundary_model, boundary_invoke,
            boundary_emit, &loop, step_defaults[index], 0};
        assert(strcmp(px_agent_run(&arena, &loop_options, NULL, "loop",
            &boundary_result), "AGENT_MAX_STEPS") == 0);
        assert(boundary_result.steps == 8);
        assert(loop.generate_calls == 8 && loop.invoke_calls == 8);
        assert(loop.event_count == 10);
        assert(strcmp(loop.events[0], "run.started") == 0);
        assert(strcmp(loop.events[9], "run.failed") == 0);
    }

    AgentBoundary unlimited_tokens = {0};
    unlimited_tokens.input_tokens = 1000000;
    unlimited_tokens.output_tokens = 1000000;
    PxAgentOptions unlimited_options = {boundary_model, boundary_invoke,
        boundary_emit, &unlimited_tokens, 2, 0};
    assert(px_agent_run(&arena, &unlimited_options, NULL, "hello",
        &boundary_result) == NULL);
    assert(boundary_result.input_tokens == 1000000);
    assert(boundary_result.output_tokens == 1000000);

    PxAgentOptions negative_token_options = {boundary_model, boundary_invoke,
        boundary_emit, &unlimited_tokens, 2, -1};
    assert(px_agent_run(&arena, &negative_token_options, NULL, "hello",
        &boundary_result) == NULL);
    assert(boundary_result.steps == 1);

    AgentBoundary equal_tokens = {0};
    equal_tokens.input_tokens = 4;
    equal_tokens.output_tokens = 6;
    PxAgentOptions equal_options = {boundary_model, boundary_invoke,
        boundary_emit, &equal_tokens, 2, 10};
    assert(px_agent_run(&arena, &equal_options, NULL, "hello",
        &boundary_result) == NULL);
    assert(boundary_result.input_tokens + boundary_result.output_tokens == 10);

    AgentBoundary over_tokens = {0};
    over_tokens.input_tokens = 4;
    over_tokens.output_tokens = 7;
    PxAgentOptions over_options = {boundary_model, boundary_invoke,
        boundary_emit, &over_tokens, 2, 10};
    assert(strcmp(px_agent_run(&arena, &over_options, NULL, "hello",
        &boundary_result), "AGENT_MAX_TOKENS") == 0);
    assert(boundary_result.steps == 0);
    assert(over_tokens.event_count == 2);
    assert(strcmp(over_tokens.events[0], "run.started") == 0);
    assert(strcmp(over_tokens.events[1], "run.failed") == 0);

    AgentBoundary invalid_usage = {0};
    invalid_usage.input_tokens = -1;
    PxAgentOptions invalid_usage_options = {boundary_model, boundary_invoke,
        boundary_emit, &invalid_usage, 2, 0};
    assert(strcmp(px_agent_run(&arena, &invalid_usage_options, NULL, "hello",
        &boundary_result), "AGENT_INVALID_USAGE") == 0);
    assert(boundary_result.steps == 0);
    assert(invalid_usage.event_count == 2);
    assert(strcmp(invalid_usage.events[1], "run.failed") == 0);

    PxCallLimit unlimited_calls;
    px_call_limit_init(&unlimited_calls, 0, -1);
    for (int index = 0; index < 3; index++) {
        assert(px_call_limit_model(&unlimited_calls) == NULL);
        assert(px_call_limit_tool(&unlimited_calls) == NULL);
    }

    PxCallLimit exact_calls;
    px_call_limit_init(&exact_calls, 2, 1);
    assert(px_call_limit_model(&exact_calls) == NULL);
    assert(px_call_limit_model(&exact_calls) == NULL);
    assert(strcmp(px_call_limit_model(&exact_calls), "AGENT_MODEL_CALL_LIMIT") == 0);
    assert(px_call_limit_tool(&exact_calls) == NULL);
    assert(strcmp(px_call_limit_tool(&exact_calls), "AGENT_TOOL_CALL_LIMIT") == 0);

    PxCallLimit other_calls;
    px_call_limit_init(&other_calls, 2, 1);
    assert(px_call_limit_model(&other_calls) == NULL);
    assert(px_call_limit_tool(&other_calls) == NULL);

    px_arena_free(&arena);
    printf("C Core API tests passed\n");
    return 0;
}
