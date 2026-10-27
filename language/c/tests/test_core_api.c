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

    PxAllowlist allow;
    px_checkpoint_init(&allow);
    assert(px_checkpoint_register(&arena, &allow, "spec.payload"));
    PxValue *value = px_parse(&arena, "{\"x\":1}");
    char *data = NULL;
    assert(px_checkpoint_marshal(&arena, &allow, "spec.payload", value, &data) == NULL);
    PxValue *decoded = NULL;
    assert(px_checkpoint_unmarshal(&arena, &allow, data, &decoded) == NULL);
    assert(px_equals(decoded, value));

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
    PxValue *wire = px_message_wire(&arena, &messages[1]);
    assert(strcmp(px_get_str(wire, "role"), "user") == 0);

    char *redacted = px_pii_redact(&arena, "email a@b.com");
    assert(strcmp(redacted, "email [REDACTED:email]") == 0);

    PxValue *schema = px_parse(&arena, "{\"type\":\"object\",\"required\":[\"name\"]}");
    PxStructuredOutput structured = {schema, 1, repair, NULL};
    assert(strcmp(px_apply_structured(&arena, &structured, "bad"), "{\"name\":\"fixed\"}") == 0);

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

    PxAgentOptions options = {static_model, NULL, NULL, NULL, 2, 0};
    PxAgentResult result;
    assert(px_agent_run(&arena, &options, NULL, "hello", &result) == NULL);
    assert(result.steps == 1 && strcmp(result.output, "ok") == 0);

    px_arena_free(&arena);
    printf("C Core API tests passed\n");
    return 0;
}
