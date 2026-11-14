#include "praxo_core.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    PxArena arena;
    px_arena_init(&arena);

    PxSink *all = px_sink_new(&arena);
    PxSink *tool = px_sink_new(&arena);
    const char *tool_kinds[] = {"tool.call"};
    PxSink *filtered = px_sink_filter(&arena, tool, tool_kinds, 1);
    PxSink *sinks[] = {all, filtered};
    PxSink *multi = px_sink_multi(&arena, sinks, 2);

    PxEvent started = {"run.started", "s1", NULL, NULL};
    PxEvent tool_call = {"tool.call", "s1", NULL, NULL};
    PxEvent completed = {"run.completed", "s1", NULL, NULL};
    px_sink_emit(multi, &started);
    px_sink_emit(multi, &tool_call);
    px_sink_emit(multi, &completed);

    const char **kinds = NULL;
    assert(px_sink_kinds(px_sink_child(multi, 0), &kinds) == 3);
    assert(strcmp(kinds[0], "run.started") == 0);
    assert(strcmp(kinds[1], "tool.call") == 0);
    assert(strcmp(kinds[2], "run.completed") == 0);
    assert(px_sink_kinds(px_sink_child(multi, 1), &kinds) == 1);
    assert(strcmp(kinds[0], "tool.call") == 0);

    px_arena_free(&arena);
    printf("C event sink example passed\n");
    return 0;
}
