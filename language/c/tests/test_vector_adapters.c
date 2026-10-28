#include "praxo_core.h"
#include "vectors_core.h"
#include "vectors_agent.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxValue *structured = px_parse(&arena,
        "{\"operation\":\"structured\",\"schema\":{\"type\":\"object\"},"
        "\"output\":\"bad\",\"repairOutput\":\"{}\",\"maxRepairs\":0}");
    PxValue *failure = px_parse(&arena,
        "{\"ok\":false,\"errorCode\":\"AGENT_STRUCTURED_OUTPUT\"}");
    assert(px_run_middleware(&arena, structured, failure));
    px_obj_set(&arena, structured, "maxRepairs", px_num(&arena, 1));
    assert(!px_run_middleware(&arena, structured, failure));
    assert(px_run_middleware(&arena, structured,
        px_parse(&arena, "{\"ok\":true,\"output\":\"{}\"}")));

    PxValue *context = px_parse(&arena,
        "{\"operation\":\"compact\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],"
        "\"budget\":{\"maxTokens\":0}}");
    PxValue *context_expect = px_parse(&arena,
        "{\"ok\":true,\"tokens\":4,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}");
    assert(px_run_context(&arena, context, context_expect));
    px_obj_set(&arena, context_expect, "tokens", px_num(&arena, 99));
    assert(!px_run_context(&arena, context, context_expect));
    px_obj_set(&arena, context_expect, "tokens", px_num(&arena, 4));
    PxValue *message = px_obj_get(context, "messages")->as.array.items[0];
    px_obj_set(&arena, message, "toolId", px_str(&arena, "cannot-represent"));
    assert(!px_run_context(&arena, context, context_expect));

    PxValue *agent = px_parse(&arena,
        "{\"prompt\":\"hi\",\"script\":[{\"content\":\"ok\"}]}");
    PxValue *agent_expect = px_parse(&arena,
        "{\"output\":\"ok\",\"steps\":1,\"toolInvocations\":0,"
        "\"events\":[\"run.started\",\"run.completed\"]}");
    assert(px_run_agent_loop(&arena, agent, agent_expect));
    px_obj_set(&arena, agent, "maxTokens", px_num(&arena, 1));
    PxValue *response = px_obj_get(agent, "script")->as.array.items[0];
    px_obj_set(&arena, response, "outputTokens", px_num(&arena, 2));
    assert(!px_run_agent_loop(&arena, agent, agent_expect));
    assert(px_run_agent_loop(&arena, agent, px_parse(&arena,
        "{\"error\":true,\"errorCode\":\"AGENT_MAX_TOKENS\",\"toolInvocations\":0,"
        "\"events\":[\"run.started\",\"run.failed\"]}")));

    px_arena_free(&arena);
    printf("C vector adapter negative controls passed\n");
    return 0;
}
