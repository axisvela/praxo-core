#include "praxo_core.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct PxSink {
    PxArena *arena;
    int mode;
    const char **kinds;
    size_t kind_count;
    PxSink *target;
    const char **predicate;
    size_t predicate_count;
    PxSink **children;
    size_t child_count;
};

static const char *copy_text(PxArena *arena, const char *text) {
    return px_arena_strdup(arena, text == NULL ? "" : text);
}

static bool same_text(const char *left, const char *right) {
    return left != NULL && right != NULL && strcmp(left, right) == 0;
}

static bool in_list(const char **values, size_t count, const char *value) {
    for (size_t index = 0; index < count; index++) {
        if (same_text(values[index], value)) {
            return true;
        }
    }
    return false;
}

void px_memory_init(PxMemoryStore *store) {
    store->records = NULL;
    store->len = 0;
    store->sequence = 0;
}

bool px_memory_put(PxArena *arena, PxMemoryStore *store, const char *session,
        const char *id, const char *frame, const char *content,
        const char *created_at, PxMemoryRecord *out) {
    PxMemoryRecord record;
    char generated[128];
    record.session = copy_text(arena, session);
    if (id == NULL || id[0] == '\0') {
        snprintf(generated, sizeof(generated), "mem-%d-%d", store->sequence, store->sequence);
        record.id = copy_text(arena, generated);
        store->sequence++;
    } else {
        record.id = copy_text(arena, id);
    }
    record.frame = copy_text(arena, frame);
    record.content = copy_text(arena, content);
    if (created_at == NULL || created_at[0] == '\0') {
        snprintf(generated, sizeof(generated), "%d", store->sequence);
        record.created_at = copy_text(arena, generated);
    } else {
        record.created_at = copy_text(arena, created_at);
    }
    PxMemoryRecord *next = px_arena_alloc(arena, sizeof(PxMemoryRecord) * (store->len + 1));
    if (store->len > 0) {
        memcpy(next, store->records, sizeof(PxMemoryRecord) * store->len);
    }
    next[store->len] = record;
    store->records = next;
    store->len++;
    if (out != NULL) {
        *out = record;
    }
    return true;
}

static bool contains_case_insensitive(const char *haystack, const char *needle) {
    size_t size = strlen(needle);
    if (size == 0) {
        return true;
    }
    for (const char *cursor = haystack; *cursor != '\0'; cursor++) {
        size_t index = 0;
        while (index < size && cursor[index] != '\0'
                && tolower((unsigned char)cursor[index]) == tolower((unsigned char)needle[index])) {
            index++;
        }
        if (index == size) {
            return true;
        }
    }
    return false;
}

static int compare_records(const void *left, const void *right) {
    const PxMemoryRecord *a = (const PxMemoryRecord *)left;
    const PxMemoryRecord *b = (const PxMemoryRecord *)right;
    return strcmp(b->created_at, a->created_at);
}

size_t px_memory_search(PxArena *arena, const PxMemoryStore *store,
        const char *session, const char *query, int limit, PxMemoryRecord **out) {
    PxMemoryRecord *matches = px_arena_alloc(arena, sizeof(PxMemoryRecord) * (store->len + 1));
    size_t count = 0;
    const char *needle = query == NULL ? "" : query;
    for (size_t index = 0; index < store->len; index++) {
        const PxMemoryRecord *record = &store->records[index];
        if (!same_text(record->session, session)) {
            continue;
        }
        if (!contains_case_insensitive(record->content, needle)) {
            continue;
        }
        matches[count++] = *record;
    }
    qsort(matches, count, sizeof(PxMemoryRecord), compare_records);
    if (limit > 0 && (size_t)limit < count) {
        count = (size_t)limit;
    }
    *out = matches;
    return count;
}

PxSink *px_sink_new(PxArena *arena) {
    PxSink *sink = px_arena_alloc(arena, sizeof(PxSink));
    memset(sink, 0, sizeof(PxSink));
    sink->arena = arena;
    return sink;
}

PxSink *px_sink_multi(PxArena *arena, PxSink **sinks, size_t count) {
    PxSink *sink = px_sink_new(arena);
    sink->mode = 1;
    sink->children = px_arena_alloc(arena, sizeof(PxSink *) * count);
    sink->child_count = count;
    for (size_t index = 0; index < count; index++) {
        sink->children[index] = sinks[index];
    }
    return sink;
}

PxSink *px_sink_filter(PxArena *arena, PxSink *target,
        const char **predicate, size_t count) {
    PxSink *sink = px_sink_new(arena);
    sink->mode = 2;
    sink->target = target;
    sink->predicate = predicate;
    sink->predicate_count = count;
    return sink;
}

void px_sink_emit(PxSink *sink, const PxEvent *event) {
    if (sink->mode == 1) {
        for (size_t index = 0; index < sink->child_count; index++) {
            px_sink_emit(sink->children[index], event);
        }
    } else if (sink->mode == 2) {
        if (sink->predicate == NULL
                || in_list(sink->predicate, sink->predicate_count, event->kind)) {
            px_sink_emit(sink->target, event);
        }
    } else {
        const char **next = px_arena_alloc(sink->arena, sizeof(char *) * (sink->kind_count + 1));
        if (sink->kind_count > 0) {
            memcpy(next, sink->kinds, sizeof(char *) * sink->kind_count);
        }
        next[sink->kind_count] = event->kind;
        sink->kinds = next;
        sink->kind_count++;
    }
}

size_t px_sink_kinds(const PxSink *sink, const char ***out) {
    if (sink->mode == 2) {
        return px_sink_kinds(sink->target, out);
    }
    if (sink->mode == 1) {
        *out = NULL;
        return 0;
    }
    *out = sink->kinds;
    return sink->kind_count;
}

size_t px_sink_child_count(const PxSink *sink) {
    return sink->child_count;
}

const PxSink *px_sink_child(const PxSink *sink, size_t index) {
    return index < sink->child_count ? sink->children[index] : NULL;
}

void px_checkpoint_init(PxAllowlist *allow) {
    allow->kinds = NULL;
    allow->len = 0;
}

bool px_checkpoint_register(PxArena *arena, PxAllowlist *allow, const char *kind) {
    if (kind == NULL || kind[0] == '\0') {
        return false;
    }
    if (in_list(allow->kinds, allow->len, kind)) {
        return true;
    }
    const char **next = px_arena_alloc(arena, sizeof(char *) * (allow->len + 1));
    if (allow->len > 0) {
        memcpy(next, allow->kinds, sizeof(char *) * allow->len);
    }
    next[allow->len] = kind;
    allow->kinds = next;
    allow->len++;
    return true;
}

const char *px_checkpoint_marshal(PxArena *arena, const PxAllowlist *allow,
        const char *kind, PxValue *value, char **out) {
    if (!in_list(allow->kinds, allow->len, kind)) {
        return "CHECKPOINT_TYPE_NOT_ALLOWED";
    }
    PxValue *envelope = px_obj(arena);
    px_obj_set(arena, envelope, "type", px_str(arena, kind));
    px_obj_set(arena, envelope, "data", value);
    *out = px_stringify(arena, envelope);
    return NULL;
}

const char *px_checkpoint_unmarshal(PxArena *arena, const PxAllowlist *allow,
        const char *data, PxValue **out) {
    PxValue *envelope = px_parse(arena, data);
    if (envelope == NULL || envelope->type != PX_OBJ) {
        return "CHECKPOINT_ERROR";
    }
    const char *kind = px_get_str(envelope, "type");
    if (kind == NULL || !in_list(allow->kinds, allow->len, kind)) {
        return "CHECKPOINT_TYPE_NOT_ALLOWED";
    }
    PxValue *value = px_obj_get(envelope, "data");
    *out = value == NULL ? px_null(arena) : value;
    return NULL;
}

static bool within(const char *root, const char *target) {
    size_t size = strlen(root);
    return strcmp(root, target) == 0
        || (strncmp(target, root, size) == 0 && target[size] == '/');
}

const char *px_normalize_path(PxArena *arena, const char *value, char **out) {
    size_t size = strlen(value);
    char *raw = px_arena_alloc(arena, size + 1);
    for (size_t index = 0; index <= size; index++) {
        raw[index] = value[index] == '\\' ? '/' : value[index];
    }
    bool absolute = false;
    char prefix[4] = {0};
    char *cursor = raw;
    if (isalpha((unsigned char)raw[0]) && raw[1] == ':') {
        prefix[0] = raw[0];
        prefix[1] = ':';
        cursor = raw + 2;
        if (*cursor == '/') {
            absolute = true;
            prefix[2] = '/';
            cursor++;
        }
    } else if (*cursor == '/') {
        absolute = true;
        prefix[0] = '/';
        cursor++;
    }
    char *parts[128];
    size_t count = 0;
    while (*cursor != '\0') {
        if (*cursor == '/') {
            cursor++;
            continue;
        }
        char *start = cursor;
        while (*cursor != '\0' && *cursor != '/') {
            cursor++;
        }
        if (*cursor == '/') {
            *cursor = '\0';
            cursor++;
        }
        if (strcmp(start, ".") == 0) {
            continue;
        }
        if (strcmp(start, "..") == 0) {
            if (count > 0 && strcmp(parts[count - 1], "..") != 0) {
                count--;
            } else if (!absolute && count < 128) {
                parts[count++] = start;
            }
            continue;
        }
        if (count < 128) {
            parts[count++] = start;
        }
    }
    char *output = px_arena_alloc(arena, size + 4);
    size_t written = 0;
    for (size_t index = 0; prefix[index] != '\0'; index++) {
        output[written++] = prefix[index];
    }
    for (size_t index = 0; index < count; index++) {
        if (written > 0 && output[written - 1] != '/') {
            output[written++] = '/';
        }
        size_t part_size = strlen(parts[index]);
        memcpy(output + written, parts[index], part_size);
        written += part_size;
    }
    output[written] = '\0';
    *out = output;
    return NULL;
}

bool px_path_checker(PxArena *arena, const PxPathGrant *grants, size_t count,
        PxPathChecker *checker, const char **code) {
    PxPathGrant *normalized = px_arena_alloc(arena, sizeof(PxPathGrant) * (count + 1));
    for (size_t index = 0; index < count; index++) {
        if (grants[index].root == NULL || grants[index].root[0] == '\0'
                || (strcmp(grants[index].access, "read") != 0
                    && strcmp(grants[index].access, "write") != 0
                    && strcmp(grants[index].access, "readwrite") != 0)) {
            *code = "POLICY_ERROR";
            return false;
        }
        char *root = NULL;
        px_normalize_path(arena, grants[index].root, &root);
        normalized[index].root = root;
        normalized[index].access = grants[index].access;
    }
    checker->grants = normalized;
    checker->len = count;
    *code = NULL;
    return true;
}

bool px_path_check(PxArena *arena, const PxPathChecker *checker,
        const char *target, const char *need, PxDecision *decision,
        const char **code) {
    decision->allowed = false;
    decision->reason = "";
    if (need == NULL || (strcmp(need, "read") != 0 && strcmp(need, "write") != 0
            && strcmp(need, "readwrite") != 0)) {
        *code = "POLICY_ERROR";
        return false;
    }
    if (checker->len == 0) {
        decision->reason = "no allowed roots";
        *code = NULL;
        return true;
    }
    char *resolved = NULL;
    px_normalize_path(arena, target, &resolved);
    for (size_t index = 0; index < checker->len; index++) {
        const PxPathGrant *grant = &checker->grants[index];
        bool access = strcmp(grant->access, "readwrite") == 0
            || (strcmp(grant->access, "read") == 0 && strcmp(need, "read") == 0)
            || (strcmp(grant->access, "write") == 0 && strcmp(need, "write") == 0);
        if (within(grant->root, resolved) && access) {
            decision->allowed = true;
            decision->reason = "allowed";
            *code = NULL;
            return true;
        }
    }
    for (size_t index = 0; index < checker->len; index++) {
        if (within(checker->grants[index].root, resolved)) {
            decision->reason = "insufficient grant";
            *code = NULL;
            return true;
        }
    }
    decision->reason = "outside roots";
    *code = NULL;
    return true;
}

bool px_path_allowed(PxArena *arena, const PxPathChecker *checker,
        const char *target, const char *need) {
    PxDecision decision;
    const char *code = NULL;
    px_path_check(arena, checker, target, need, &decision, &code);
    return code == NULL && decision.allowed;
}

static PxValue *agent_fail(const PxAgentOptions *options, const char *code) {
    if (options->emit != NULL) {
        options->emit("run.failed", options->ctx);
    }
    return (PxValue *)code;
}

const char *px_agent_run(PxArena *arena, const PxAgentOptions *options,
        PxValue *session_messages, const char *prompt, PxAgentResult *result) {
    result->output = "";
    result->steps = 0;
    result->input_tokens = 0;
    result->output_tokens = 0;
    if (options == NULL || options->generate == NULL) {
        return "AGENT_INVALID_OPTIONS";
    }
    PxValue *messages = px_arr(arena);
    if (session_messages != NULL && session_messages->type == PX_ARR) {
        for (size_t index = 0; index < session_messages->as.array.len; index++) {
            px_arr_push(arena, messages, session_messages->as.array.items[index]);
        }
    }
    PxValue *user = px_obj(arena);
    px_obj_set(arena, user, "role", px_str(arena, "user"));
    px_obj_set(arena, user, "content", px_str(arena, prompt));
    px_arr_push(arena, messages, user);
    int limit = options->max_steps > 0 ? options->max_steps : 8;
    if (options->emit != NULL) {
        options->emit("run.started", options->ctx);
    }
    for (int step = 1; step <= limit; step++) {
        PxValue *response = options->generate(arena, messages, NULL, options->ctx);
        if (response == NULL || response->type != PX_OBJ) {
            agent_fail(options, "MODEL_ERROR");
            return "MODEL_ERROR";
        }
        const char *content = px_get_str(response, "content");
        if (content == NULL) {
            content = "";
        }
        double input = px_get_num(response, "inputTokens", 0);
        double output = px_get_num(response, "outputTokens", 0);
        if (input < 0 || output < 0) {
            agent_fail(options, "AGENT_INVALID_USAGE");
            return "AGENT_INVALID_USAGE";
        }
        result->input_tokens += (long)input;
        result->output_tokens += (long)output;
        if (options->max_tokens > 0
                && result->input_tokens + result->output_tokens > options->max_tokens) {
            agent_fail(options, "AGENT_MAX_TOKENS");
            return "AGENT_MAX_TOKENS";
        }
        PxValue *assistant = px_obj(arena);
        px_obj_set(arena, assistant, "role", px_str(arena, "assistant"));
        px_obj_set(arena, assistant, "content", px_str(arena, content));
        PxValue *calls = px_obj_get(response, "toolCalls");
        if (calls != NULL && calls->type == PX_ARR) {
            px_obj_set(arena, assistant, "toolCalls", calls);
        }
        px_arr_push(arena, messages, assistant);
        result->steps = step;
        if (calls == NULL || calls->type != PX_ARR || calls->as.array.len == 0) {
            result->output = content;
            if (options->emit != NULL) {
                options->emit("run.completed", options->ctx);
            }
            return NULL;
        }
        for (size_t index = 0; index < calls->as.array.len; index++) {
            PxValue *call = calls->as.array.items[index];
            if (call == NULL || call->type != PX_OBJ) {
                agent_fail(options, "MODEL_ERROR");
                return "MODEL_ERROR";
            }
            const char *name = px_get_str(call, "name");
            const char *id = px_get_str(call, "id");
            PxValue *arguments = px_obj_get(call, "arguments");
            if (name == NULL || id == NULL || arguments == NULL) {
                agent_fail(options, "MODEL_ERROR");
                return "MODEL_ERROR";
            }
            if (options->emit != NULL) {
                options->emit("tool.call", options->ctx);
            }
            PxValue *value = options->invoke == NULL ? arguments
                : options->invoke(arena, name, arguments, options->ctx);
            PxValue *message = px_obj(arena);
            px_obj_set(arena, message, "role", px_str(arena, "tool"));
            px_obj_set(arena, message, "toolId", px_str(arena, id));
            px_obj_set(arena, message, "content",
                px_str(arena, value == NULL ? "null" : px_stringify(arena, value)));
            px_arr_push(arena, messages, message);
        }
    }
    agent_fail(options, "AGENT_MAX_STEPS");
    return "AGENT_MAX_STEPS";
}
