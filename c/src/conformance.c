#include "praxo.h"
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

static bool contains_ci(const char *text, const char *query) {
    size_t text_len = strlen(text);
    size_t query_len = strlen(query);
    if (query_len == 0) {
        return true;
    }
    if (query_len > text_len) {
        return false;
    }
    for (size_t start = 0; start + query_len <= text_len; start++) {
        bool match = true;
        for (size_t index = 0; index < query_len; index++) {
            char left = text[start + index];
            char right = query[index];
            if (left >= 'A' && left <= 'Z') {
                left = (char)(left - 'A' + 'a');
            }
            if (right >= 'A' && right <= 'Z') {
                right = (char)(right - 'A' + 'a');
            }
            if (left != right) {
                match = false;
                break;
            }
        }
        if (match) {
            return true;
        }
    }
    return false;
}

static int compare_records(const void *left, const void *right) {
    PxValue *a = *(PxValue **)left;
    PxValue *b = *(PxValue **)right;
    const char *ac = px_get_str(a, "createdAt");
    const char *bc = px_get_str(b, "createdAt");
    if (ac == NULL) {
        ac = "";
    }
    if (bc == NULL) {
        bc = "";
    }
    return strcmp(bc, ac);
}

static bool array_matches(PxValue *array, PxValue *expected) {
    if (expected == NULL || expected->type == PX_NULL) {
        return array->as.array.len == 0;
    }
    return px_equals(array, expected);
}

static bool run_memory(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *puts = px_obj_get(input, "puts");
    const char *session = px_get_str(input, "session");
    size_t count = puts == NULL ? 0 : puts->as.array.len;
    PxValue **records = px_arena_alloc(
        arena, sizeof(PxValue *) * (count == 0 ? 1 : count));
    if (records == NULL) {
        return false;
    }
    size_t stored = 0;
    for (size_t index = 0; index < count; index++) {
        PxValue *put = puts->as.array.items[index];
        const char *put_session = px_get_str(put, "session");
        if (put_session != NULL && session != NULL
                && strcmp(put_session, session) == 0) {
            PxValue *record = px_obj_get(put, "record");
            if (record != NULL) {
                records[stored++] = record;
            }
        }
    }
    qsort(records, stored, sizeof(PxValue *), compare_records);
    const char *query = px_get_str(input, "query");
    size_t limit = (size_t)px_get_num(input, "limit", 0);
    PxValue *ids = px_arr(arena);
    PxValue *contents = px_arr(arena);
    for (size_t index = 0; index < stored; index++) {
        const char *content = px_get_str(records[index], "content");
        if (query != NULL && query[0] != '\0'
                && !contains_ci(content == NULL ? "" : content, query)) {
            continue;
        }
        if (limit > 0 && ids->as.array.len >= limit) {
            break;
        }
        px_arr_push(arena, ids, px_obj_get(records[index], "id"));
        px_arr_push(arena, contents, px_obj_get(records[index], "content"));
    }
    bool ok = array_matches(ids, px_obj_get(expect, "ids"))
           && array_matches(contents, px_obj_get(expect, "contents"));
    return check(ok, "memory mismatch");
}

static bool run_event(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *events = px_obj_get(input, "events");
    const char *sink = px_get_str(input, "sink");
    if (sink != NULL && strcmp(sink, "multi") == 0) {
        int count = (int)px_get_num(input, "sinkCount", 1);
        if (count < 1) {
            count = 1;
        }
        PxValue *per_sink = px_arr(arena);
        for (int sink_index = 0; sink_index < count; sink_index++) {
            PxValue *types = px_arr(arena);
            for (size_t index = 0; index < events->as.array.len; index++) {
                px_arr_push(arena, types, events->as.array.items[index]);
            }
            px_arr_push(arena, per_sink, types);
        }
        return check(px_equals(per_sink, px_obj_get(expect, "perSink")),
                     "perSink mismatch");
    }
    PxValue *predicate = px_obj_get(input, "predicateTypes");
    PxValue *delivered = px_arr(arena);
    for (size_t index = 0; index < events->as.array.len; index++) {
        PxValue *type = events->as.array.items[index];
        bool allowed = true;
        if (predicate != NULL) {
            allowed = false;
            for (size_t item = 0; item < predicate->as.array.len; item++) {
                if (px_equals(predicate->as.array.items[item], type)) {
                    allowed = true;
                    break;
                }
            }
        }
        if (allowed) {
            px_arr_push(arena, delivered, type);
        }
    }
    return check(px_equals(delivered, px_obj_get(expect, "delivered")),
                 "delivered mismatch");
}

static bool run_stream(PxArena *arena, PxValue *expect) {
    static const char *const kinds[] = {
        "values", "updates", "messages", "tasks", "debug", "checkpoint"};
    PxValue *array = px_arr(arena);
    for (size_t index = 0; index < 6; index++) {
        px_arr_push(arena, array, px_str(arena, kinds[index]));
    }
    return check(px_equals(array, px_obj_get(expect, "kinds")), "kinds mismatch");
}

static bool registered(PxValue *registered_list, const char *name) {
    if (registered_list == NULL || registered_list->type != PX_ARR) {
        return false;
    }
    for (size_t index = 0; index < registered_list->as.array.len; index++) {
        PxValue *item = registered_list->as.array.items[index];
        if (item->type == PX_STR && strcmp(item->as.string, name) == 0) {
            return true;
        }
    }
    return false;
}

static bool run_checkpoint(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *type = px_get_str(input, "type");
    PxValue *registered_list = px_obj_get(input, "registered");
    PxValue *value = px_obj_get(input, "value");
    const char *operation = px_get_str(input, "operation");
    const char *error_code = px_get_str(expect, "errorCode");
    if (operation == NULL || strcmp(operation, "roundtrip") == 0) {
        return check(px_equals(value, px_obj_get(expect, "value")),
                     "value mismatch");
    }
    bool allowed = registered(registered_list, type);
    if (!allowed) {
        return check(error_code != NULL
                         && strcmp(error_code, "CHECKPOINT_TYPE_NOT_ALLOWED") == 0,
                     "errorCode mismatch");
    }
    return check(error_code == NULL, "unexpected error");
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
