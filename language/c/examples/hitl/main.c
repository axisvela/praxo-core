#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

typedef struct {
    int model_step;
    int effects;
    const char *text;
    const char *visibility;
} State;

static PxValue *write_model(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx) {
    (void)messages;
    (void)tools;
    State *state = ctx;
    if (state->model_step++ == 0) {
        return px_parse(arena,
            "{\"toolCalls\":[{\"id\":\"call-1\",\"name\":\"write_note\","
            "\"arguments\":{\"text\":\"hello\",\"visibility\":\"public\"}}]}");
    }
    return px_parse(arena, "{\"content\":\"done\"}");
}

static PxValue *write_note(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    (void)arena;
    (void)name;
    State *state = ctx;
    state->effects++;
    state->text = px_get_str(arguments, "text");
    state->visibility = px_get_str(arguments, "visibility");
    return arguments;
}

static const char *authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)ctx;
    if (strcmp(kind, "tool.invoke") != 0) {
        return NULL;
    }
    if (tool_name == NULL || strcmp(tool_name, "write_note") != 0) {
        return "AGENT_POLICY_DENIED";
    }
    const char *visibility = px_get_str(arguments, "visibility");
    if (visibility == NULL || strcmp(visibility, "public") != 0) {
        return "AGENT_POLICY_DENIED";
    }
    return NULL;
}

static const PxInterruptDecision *approve(const char *name, PxValue *arguments,
        void *ctx) {
    (void)name;
    (void)arguments;
    (void)ctx;
    static const PxInterruptDecision decision = {"approve", NULL, NULL, NULL};
    return &decision;
}

static PxValue *edited_arguments;

static const PxInterruptDecision *edit(const char *name, PxValue *arguments,
        void *ctx) {
    (void)name;
    (void)arguments;
    (void)ctx;
    static const PxInterruptDecision decision = {"edit", NULL, NULL, NULL};
    static PxInterruptDecision current;
    current = decision;
    current.arguments = edited_arguments;
    return &current;
}

static const char *interrupt_tools[] = {"write_note"};

static int run(PxArena *arena, State *state, PxInterruptHandler decision,
        PxAgentResult *result) {
    PxAgentOptions options = {
        .generate = write_model,
        .invoke = write_note,
        .ctx = state,
        .max_steps = 4,
        .authorize = authorize,
        .interrupt_on = interrupt_tools,
        .interrupt_on_count = 1,
        .on_interrupt = decision,
    };
    return px_agent_run(arena, &options, NULL, "write", result) == NULL;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    State approved = {0};
    PxAgentResult result;
    if (!run(&arena, &approved, approve, &result) || approved.effects != 1) {
        fprintf(stderr, "approve failed\n");
        return 1;
    }
    printf("approve: written; effects=%d\n", approved.effects);

    State edited = {0};
    edited_arguments = px_parse(&arena,
        "{\"text\":\"hello\",\"visibility\":\"private\"}");
    const char *error = NULL;
    PxAgentOptions options = {
        .generate = write_model,
        .invoke = write_note,
        .ctx = &edited,
        .max_steps = 4,
        .authorize = authorize,
        .interrupt_on = interrupt_tools,
        .interrupt_on_count = 1,
        .on_interrupt = edit,
    };
    error = px_agent_run(&arena, &options, NULL, "write", &result);
    if (error == NULL || strcmp(error, "AGENT_POLICY_DENIED") != 0) {
        fprintf(stderr, "edit error: %s\n", error == NULL ? "" : error);
        return 1;
    }
    if (edited.effects != 0) {
        fprintf(stderr, "edit effects: %d\n", edited.effects);
        return 1;
    }
    printf("edit: policy rejected; effects=%d\n", edited.effects);

    px_arena_free(&arena);
    return 0;
}
