#include "praxo.h"
#include "praxo_core.h"
#include "jsonschema.h"
#include "plugin.h"
#include "toolcall.h"
#include "vectors_agent.h"
#include "vectors_core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *file;
    const char *group;
    bool implemented;
} VectorGroup;

static const VectorGroup GROUPS[] = {
    {"toolcall.json", "toolcall", true},
    {"jsonschema.json", "jsonschema", true},
    {"plugin.json", "plugin", true},
    {"checkpoint.json", "checkpoint", true},
    {"event.json", "event", true},
    {"memory.json", "memory", true},
    {"policy.json", "policy", true},
    {"stream.json", "stream", true},
    {"context.json", "context", true},
    {"middleware.json", "middleware", true},
    {"agent-loop.json", "agent-loop", true},
};

static bool check(bool condition, const char *detail) {
    if (!condition) {
        fprintf(stderr, "  %s\n", detail);
    }
    return condition;
}

static bool run_toolcall(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *operation = px_get_str(input, "operation");
    const char *content = px_get_str(input, "content");
    if (operation != NULL && strcmp(operation, "strip") == 0) {
        const char *text = px_get_str(expect, "text");
        char *got = px_strip_toolcall(arena, content == NULL ? "" : content);
        return check(strcmp(got, text == NULL ? "" : text) == 0, "strip mismatch");
    }
    PxToolCall *call = px_parse_toolcall(arena, content == NULL ? "" : content);
    if (px_get_bool(expect, "nil", false)) {
        return check(call == NULL, "expected nil");
    }
    if (call == NULL) {
        return check(false, "expected tool call");
    }
    const char *name = px_get_str(expect, "name");
    if (!check(name != NULL && strcmp(call->name, name) == 0, "name mismatch")) {
        return false;
    }
    PxValue *want = px_obj_get(expect, "input");
    if (want == NULL) {
        want = px_obj(arena);
    }
    return check(px_equals(call->input, want), "input mismatch");
}

static bool run_jsonschema(
    PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *errors = px_arr(arena);
    px_schema_validate(
        arena, px_obj_get(input, "schema"), px_obj_get(input, "data"),
        "$", errors);
    bool valid = errors->as.array.len == 0;
    if (!check(valid == px_get_bool(expect, "valid", false), "valid mismatch")) {
        return false;
    }
    PxValue *paths = px_arr(arena);
    for (size_t index = 0; index < errors->as.array.len; index++) {
        px_arr_push(arena, paths, px_obj_get(errors->as.array.items[index], "path"));
    }
    PxValue *want = px_obj_get(expect, "errorPaths");
    if (want == NULL) {
        want = px_arr(arena);
    }
    return check(px_equals(paths, want), "errorPaths mismatch");
}

static bool run_plugin(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *manifest = px_obj_get(input, "manifest");
    const char *raw = px_get_str(input, "raw");
    if (raw != NULL) {
        manifest = px_parse(arena, raw);
    }
    const char *id = NULL;
    const char *kind = NULL;
    bool valid = px_plugin_validate(manifest, &id, &kind);
    if (!check(valid == px_get_bool(expect, "valid", false), "valid mismatch")) {
        return false;
    }
    if (!valid) {
        return true;
    }
    const char *want_id = px_get_str(expect, "id");
    if (want_id != NULL && !check(id != NULL && strcmp(id, want_id) == 0, "id mismatch")) {
        return false;
    }
    const char *want_kind = px_get_str(expect, "kind");
    if (want_kind != NULL
            && !check(kind != NULL && strcmp(kind, want_kind) == 0, "kind mismatch")) {
        return false;
    }
    return true;
}

static bool array_matches(PxValue *array, PxValue *expected) {
    if (expected == NULL || expected->type == PX_NULL) {
        return array->as.array.len == 0;
    }
    return px_equals(array, expected);
}

static bool run_memory(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *puts = px_obj_get(input, "puts");
    size_t count = puts == NULL ? 0 : puts->as.array.len;
    PxMemoryStore store;
    px_memory_init(&store);
    for (size_t index = 0; index < count; index++) {
        PxValue *put = puts->as.array.items[index];
        PxValue *record = px_obj_get(put, "record");
        if (!px_memory_put(arena, &store, px_get_str(put, "session"),
                px_get_str(record, "id"), px_get_str(record, "frame"),
                px_get_str(record, "content"), px_get_str(record, "createdAt"), NULL)) {
            return check(false, "memory put failed");
        }
    }
    PxMemoryRecord *records = NULL;
    size_t found = px_memory_search(arena, &store, px_get_str(input, "session"),
        px_get_str(input, "query"), (int)px_get_num(input, "limit", 0), &records);
    PxValue *ids = px_arr(arena);
    PxValue *contents = px_arr(arena);
    for (size_t index = 0; index < found; index++) {
        px_arr_push(arena, ids, px_str(arena, records[index].id));
        px_arr_push(arena, contents, px_str(arena, records[index].content));
    }
    bool ok = array_matches(ids, px_obj_get(expect, "ids"))
           && array_matches(contents, px_obj_get(expect, "contents"));
    return check(ok, "memory mismatch");
}

static PxValue *sink_kinds(PxArena *arena, const PxSink *sink) {
    const char **kinds = NULL;
    size_t count = px_sink_kinds(sink, &kinds);
    PxValue *out = px_arr(arena);
    for (size_t index = 0; index < count; index++) {
        px_arr_push(arena, out, px_str(arena, kinds[index]));
    }
    return out;
}

static bool run_event(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *events = px_obj_get(input, "events");
    const char *kind = px_get_str(input, "sink");
    PxSink *sink;
    bool multi = kind != NULL && strcmp(kind, "multi") == 0;
    if (multi) {
        int count = (int)px_get_num(input, "sinkCount", 1);
        if (count < 1) {
            count = 1;
        }
        PxSink **children = px_arena_alloc(arena, sizeof(PxSink *) * (size_t)count);
        for (int sink_index = 0; sink_index < count; sink_index++) {
            children[sink_index] = px_sink_new(arena);
        }
        sink = px_sink_multi(arena, children, (size_t)count);
    } else {
        PxValue *predicate = px_obj_get(input, "predicateTypes");
        size_t count = predicate == NULL ? 0 : predicate->as.array.len;
        const char **types = predicate == NULL ? NULL
            : px_arena_alloc(arena, sizeof(char *) * (count + 1));
        if (predicate != NULL) {
            for (size_t index = 0; index < count; index++) {
                types[index] = predicate->as.array.items[index]->as.string;
            }
        }
        sink = px_sink_filter(arena, px_sink_new(arena), types, count);
    }
    for (size_t index = 0; index < events->as.array.len; index++) {
        PxEvent event = {events->as.array.items[index]->as.string, NULL, NULL, NULL};
        px_sink_emit(sink, &event);
    }
    if (multi) {
        PxValue *per_sink = px_arr(arena);
        for (size_t index = 0; index < px_sink_child_count(sink); index++) {
            px_arr_push(arena, per_sink, sink_kinds(arena, px_sink_child(sink, index)));
        }
        return check(px_equals(per_sink, px_obj_get(expect, "perSink")), "perSink mismatch");
    }
    return check(px_equals(sink_kinds(arena, sink), px_obj_get(expect, "delivered")),
                 "delivered mismatch");
}

static bool run_stream(PxArena *arena, PxValue *expect) {
    const char **kinds = NULL;
    size_t count = px_stream_kinds(&kinds);
    PxValue *array = px_arr(arena);
    for (size_t index = 0; index < count; index++) {
        px_arr_push(arena, array, px_str(arena, kinds[index]));
    }
    return check(px_equals(array, px_obj_get(expect, "kinds")), "kinds mismatch");
}

static bool run_checkpoint(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *type = px_get_str(input, "type");
    PxValue *registered_list = px_obj_get(input, "registered");
    PxValue *value = px_obj_get(input, "value");
    const char *operation = px_get_str(input, "operation");
    PxAllowlist allow;
    px_checkpoint_init(&allow);
    if (registered_list != NULL) {
        for (size_t index = 0; index < registered_list->as.array.len; index++) {
            if (!px_checkpoint_register(arena, &allow,
                    registered_list->as.array.items[index]->as.string)) {
                return check(false, "checkpoint registration failed");
            }
        }
    }
    const char *code;
    PxValue *decoded = NULL;
    char *data = NULL;
    if (operation != NULL && strcmp(operation, "unmarshal") == 0) {
        PxValue *envelope = px_obj(arena);
        px_obj_set(arena, envelope, "type", px_str(arena, type));
        px_obj_set(arena, envelope, "data", value);
        code = px_checkpoint_unmarshal(arena, &allow, px_stringify(arena, envelope), &decoded);
    } else {
        code = px_checkpoint_marshal(arena, &allow, type, value, &data);
        if (code == NULL && (operation == NULL || strcmp(operation, "roundtrip") == 0)) {
            code = px_checkpoint_unmarshal(arena, &allow, data, &decoded);
        }
    }
    const char *want_code = px_get_str(expect, "errorCode");
    if (code != NULL || want_code != NULL) {
        return check(code != NULL && want_code != NULL && strcmp(code, want_code) == 0,
            "checkpoint errorCode mismatch");
    }
    PxValue *want = px_obj_get(expect, "value");
    return check(want == NULL || px_equals(decoded, want), "checkpoint value mismatch");
}

static int run_file(const char *root, const VectorGroup *group) {
    char path[2400];
    snprintf(path, sizeof(path), "%s/spec/vectors/%s", root, group->file);
    char *text = px_read_file(path);
    if (text == NULL) {
        fprintf(stderr, "%s: cannot read\n", group->file);
        return 1;
    }
    PxArena arena;
    px_arena_init(&arena);
    PxValue *file = px_parse(&arena, text);
    free(text);
    if (file == NULL) {
        fprintf(stderr, "%s: invalid JSON\n", group->file);
        px_arena_free(&arena);
        return 1;
    }
    if (!group->implemented) {
        printf("  skip %s (C agent groups pending)\n", group->group);
        px_arena_free(&arena);
        return 0;
    }
    PxValue *vectors = px_obj_get(file, "vectors");
    if (vectors == NULL || vectors->type != PX_ARR) {
        px_arena_free(&arena);
        return 1;
    }
    int failures = 0;
    for (size_t index = 0; index < vectors->as.array.len; index++) {
        PxValue *vector = vectors->as.array.items[index];
        const char *id = px_get_str(vector, "id");
        PxValue *input = px_obj_get(vector, "input");
        PxValue *expect = px_obj_get(vector, "expect");
        bool ok = false;
        if (strcmp(group->group, "toolcall") == 0) {
            ok = run_toolcall(&arena, input, expect);
        } else if (strcmp(group->group, "jsonschema") == 0) {
            ok = run_jsonschema(&arena, input, expect);
        } else if (strcmp(group->group, "plugin") == 0) {
            ok = run_plugin(&arena, input, expect);
        } else if (strcmp(group->group, "memory") == 0) {
            ok = run_memory(&arena, input, expect);
        } else if (strcmp(group->group, "event") == 0) {
            ok = run_event(&arena, input, expect);
        } else if (strcmp(group->group, "stream") == 0) {
            ok = run_stream(&arena, expect);
        } else if (strcmp(group->group, "checkpoint") == 0) {
            ok = run_checkpoint(&arena, input, expect);
        } else if (strcmp(group->group, "policy") == 0) {
            ok = px_run_policy(&arena, input, expect);
        } else if (strcmp(group->group, "context") == 0) {
            ok = px_run_context(&arena, input, expect);
        } else if (strcmp(group->group, "middleware") == 0) {
            ok = px_run_middleware(&arena, input, expect);
        } else if (strcmp(group->group, "agent-loop") == 0) {
            ok = px_run_agent_loop(&arena, input, expect);
        }
        if (!ok) {
            fprintf(stderr, "%s/%s: failed\n", group->group, id);
            failures++;
        }
    }
    printf("%s: %zu fixtures, %d failures\n", group->group, vectors->as.array.len, failures);
    px_arena_free(&arena);
    return failures;
}

int px_run_conformance(const char *root) {
    int failures = 0;
    for (size_t index = 0; index < sizeof(GROUPS) / sizeof(GROUPS[0]); index++) {
        failures += run_file(root, &GROUPS[index]);
    }
    if (failures == 0) {
        printf("all spec vectors passed\n");
        return 0;
    }
    fprintf(stderr, "%d C vector(s) failed\n", failures);
    return 1;
}
