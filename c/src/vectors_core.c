#include "vectors_core.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#include <direct.h>
#define MKDIR(path) _mkdir(path)
#define RMDIR(path) _rmdir(path)
#else
#include <sys/stat.h>
#include <unistd.h>
#define MKDIR(path) mkdir(path, 0755)
#define RMDIR(path) rmdir(path)
#endif

static bool check(bool condition, const char *detail) {
    if (!condition) {
        fprintf(stderr, "  %s\n", detail);
    }
    return condition;
}

static void normalize_path(
    const char *base, const char *value, char *out, size_t size) {
    char raw[2048];
    if (value[0] == '/' || value[0] == '\\'
            || (isalpha((unsigned char)value[0]) && value[1] == ':')) {
        snprintf(raw, sizeof(raw), "%s", value);
    } else {
        snprintf(raw, sizeof(raw), "%s/%s", base, value);
    }
    for (char *cursor = raw; *cursor != '\0'; cursor++) {
        if (*cursor == '\\') {
            *cursor = '/';
        }
    }
    char drive[3] = {0};
    char *cursor = raw;
    bool absolute = false;
    if (isalpha((unsigned char)raw[0]) && raw[1] == ':') {
        drive[0] = raw[0];
        drive[1] = ':';
        cursor = raw + 2;
    }
    if (*cursor == '/') {
        absolute = true;
        cursor++;
    }
    char *parts[128];
    size_t count = 0;
    while (*cursor != '\0') {
        while (*cursor == '/') {
            cursor++;
        }
        if (*cursor == '\0') {
            break;
        }
        char *start = cursor;
        while (*cursor != '\0' && *cursor != '/') {
            cursor++;
        }
        if (*cursor != '\0') {
            *cursor = '\0';
            cursor++;
        }
        if (strcmp(start, ".") == 0) {
            continue;
        }
        if (strcmp(start, "..") == 0) {
            if (count > 0) {
                count--;
            }
            continue;
        }
        if (count < 128) {
            parts[count++] = start;
        }
    }
    size_t index = 0;
    if (drive[0] != '\0') {
        index += (size_t)snprintf(out + index, size - index, "%s", drive);
    }
    if (absolute || drive[0] != '\0') {
        index += (size_t)snprintf(out + index, size - index, "/");
    }
    for (size_t part = 0; part < count; part++) {
        index += (size_t)snprintf(
            out + index, size - index, "%s%s",
            part == 0 ? "" : "/", parts[part]);
    }
    if (index == 0) {
        snprintf(out, size, "/");
    }
}

static bool path_within(const char *root, const char *target) {
    size_t root_len = strlen(root);
    bool windows = false;
#ifdef _WIN32
    windows = true;
#endif
    for (size_t index = 0; index < root_len && index < strlen(target); index++) {
        char left = root[index];
        char right = target[index];
        if (windows) {
            left = (char)tolower((unsigned char)left);
            right = (char)tolower((unsigned char)right);
        }
        if (left != right) {
            return false;
        }
    }
    if (strlen(target) == root_len) {
        return true;
    }
    return target[root_len] == '/';
}

static bool access_allows(const char *grant, const char *need) {
    if (strcmp(need, "read") == 0) {
        return strcmp(grant, "read") == 0 || strcmp(grant, "readwrite") == 0;
    }
    if (strcmp(need, "write") == 0) {
        return strcmp(grant, "write") == 0 || strcmp(grant, "readwrite") == 0;
    }
    return strcmp(grant, "readwrite") == 0;
}

bool px_run_policy(PxArena *arena, PxValue *input, PxValue *expect) {
    const char *temp = getenv("TEMP");
    if (temp == NULL) {
        temp = ".";
    }
    char base[1024];
    snprintf(base, sizeof(base), "%s/praxo-policy-%ld", temp, (long)time(NULL));
    MKDIR(base);
    const char *need = px_get_str(input, "need");
    if (need == NULL) {
        need = "read";
    }
    PxValue *make_dirs = px_obj_get(input, "makeDirs");
    if (make_dirs != NULL && make_dirs->type == PX_ARR) {
        for (size_t index = 0; index < make_dirs->as.array.len; index++) {
            char path[1200];
            snprintf(path, sizeof(path), "%s/%s", base,
                     make_dirs->as.array.items[index]->as.string);
            MKDIR(path);
        }
    }
    PxValue *grants = px_obj_get(input, "grants");
    size_t grant_count = grants == NULL ? 0 : grants->as.array.len;
    char roots[64][1200];
    const char *accesses[64];
    size_t stored = 0;
    for (size_t index = 0; index < grant_count && stored < 64; index++) {
        PxValue *grant = grants->as.array.items[index];
        const char *root_value = px_get_str(grant, "root");
        const char *access = px_get_str(grant, "access");
        if (root_value == NULL || access == NULL) {
            continue;
        }
        char path[1200];
        normalize_path(base, root_value, roots[stored], sizeof(roots[stored]));
        snprintf(path, sizeof(path), "%s", roots[stored]);
        MKDIR(path);
        accesses[stored] = access;
        stored++;
    }
    bool invalid_access = strcmp(need, "read") != 0
                       && strcmp(need, "write") != 0
                       && strcmp(need, "readwrite") != 0;
    bool expected_error = px_get_bool(expect, "error", false);
    if (invalid_access) {
        RMDIR(base);
        return check(expected_error, "expected policy error");
    }
    if (expected_error) {
        RMDIR(base);
        return check(false, "expected policy error");
    }
    char target[1200];
    normalize_path(base, px_get_str(input, "target"), target, sizeof(target));
    bool allowed = false;
    for (size_t index = 0; index < stored; index++) {
        if (path_within(roots[index], target)) {
            allowed = access_allows(accesses[index], need);
            break;
        }
    }
    RMDIR(base);
    return check(allowed == px_get_bool(expect, "allowed", false),
                 "allowed mismatch");
}

static size_t estimate_tokens(PxArena *arena, PxValue *messages) {
    size_t total = 0;
    if (messages == NULL || messages->type != PX_ARR) {
        return 0;
    }
    for (size_t index = 0; index < messages->as.array.len; index++) {
        PxValue *message = messages->as.array.items[index];
        const char *content = px_get_str(message, "content");
        const char *tool_id = px_get_str(message, "toolId");
        total += 4 + (content == NULL ? 0 : strlen(content)) / 4;
        total += (tool_id == NULL ? 0 : strlen(tool_id)) / 4;
        PxValue *blocks = px_obj_get(message, "contentBlocks");
        if (blocks != NULL && blocks->type == PX_ARR) {
            for (size_t block = 0; block < blocks->as.array.len; block++) {
                PxValue *item = blocks->as.array.items[block];
                const char *text = px_get_str(item, "text");
                const char *image = px_get_str(item, "image_url");
                const char *data = px_get_str(item, "data");
                total += 4 + (text == NULL ? 0 : strlen(text)) / 4;
                total += (image == NULL ? 0 : strlen(image)) / 4;
                total += (data == NULL ? 0 : strlen(data)) / 4;
            }
        }
        PxValue *calls = px_obj_get(message, "toolCalls");
        if (calls != NULL && calls->type == PX_ARR) {
            for (size_t call = 0; call < calls->as.array.len; call++) {
                PxValue *item = calls->as.array.items[call];
                const char *name = px_get_str(item, "name");
                total += 4 + (name == NULL ? 0 : strlen(name)) / 4;
                PxValue *arguments = px_obj_get(item, "arguments");
                if (arguments != NULL) {
                    char *raw = px_stringify(arena, arguments);
                    total += strlen(raw) / 4;
                }
            }
        }
    }
    return total;
}

static char *substring_copy(PxArena *arena, const char *content, size_t size);

static char *truncate_tokens(
    PxArena *arena, const char *content, size_t tokens) {
    if (tokens == 0) {
        return px_arena_strdup(arena, "");
    }
    size_t limit = tokens * 4;
    size_t length = content == NULL ? 0 : strlen(content);
    if (length <= limit) {
        return px_arena_strdup(arena, content == NULL ? "" : content);
    }
    if (limit <= 16) {
        return substring_copy(arena, content, limit);
    }
    char *out = px_arena_alloc(arena, limit - 16 + 13);
    memcpy(out, content, limit - 16);
    memcpy(out + limit - 16, "\n[truncated]", 13);
    return out;
}

static char *substring_copy(PxArena *arena, const char *content, size_t size) {
    char *out = px_arena_alloc(arena, size + 1);
    memcpy(out, content, size);
    out[size] = '\0';
    return out;
}

static PxValue *clone_with_content(
    PxArena *arena, PxValue *message, const char *content) {
    PxValue *out = px_obj(arena);
    px_obj_set(arena, out, "role", px_obj_get(message, "role"));
    px_obj_set(arena, out, "content", px_str(arena, content));
    PxValue *blocks = px_obj_get(message, "contentBlocks");
    if (blocks != NULL) {
        px_obj_set(arena, out, "contentBlocks", blocks);
    }
    PxValue *calls = px_obj_get(message, "toolCalls");
    if (calls != NULL) {
        px_obj_set(arena, out, "toolCalls", calls);
    }
    PxValue *tool_id = px_obj_get(message, "toolId");
    if (tool_id != NULL) {
        px_obj_set(arena, out, "toolId", tool_id);
    }
    return out;
}

static bool starts_with(const char *text, const char *prefix) {
    return strncmp(text, prefix, strlen(prefix)) == 0;
}

static PxValue *build_compacted(
    PxArena *arena,
    PxValue **system,
    size_t system_count,
    PxValue *marker,
    bool include_marker,
    PxValue **kept,
    size_t kept_count) {
    PxValue *out = px_arr(arena);
    for (size_t index = 0; index < system_count; index++) {
        px_arr_push(arena, out, system[index]);
    }
    if (include_marker) {
        px_arr_push(arena, out, marker);
    }
    for (size_t index = 0; index < kept_count; index++) {
        px_arr_push(arena, out, kept[index]);
    }
    return out;
}

bool px_run_context(PxArena *arena, PxValue *input, PxValue *expect) {
    PxValue *messages = px_obj_get(input, "messages");
    const char *operation = px_get_str(input, "operation");
    if (operation != NULL && strcmp(operation, "estimate") == 0) {
        size_t got = estimate_tokens(arena, messages);
        return check(got == (size_t)px_get_num(expect, "tokens", 0),
                     "tokens mismatch");
    }
    PxValue *budget = px_obj_get(input, "budget");
    size_t max_tokens = (size_t)px_get_num(budget, "maxTokens", 0);
    size_t keep = (size_t)px_get_num(budget, "keepRecent", 0);
    if (max_tokens == 0 || estimate_tokens(arena, messages) <= max_tokens) {
        return check(px_equals(messages, px_obj_get(expect, "messages")),
                     "messages mismatch");
    }
    size_t count = messages == NULL ? 0 : messages->as.array.len;
    PxValue **system = px_arena_alloc(arena, sizeof(PxValue *) * (count == 0 ? 1 : count));
    PxValue **rest = px_arena_alloc(arena, sizeof(PxValue *) * (count == 0 ? 1 : count));
    size_t system_count = 0;
    size_t rest_count = 0;
    for (size_t index = 0; index < count; index++) {
        PxValue *message = messages->as.array.items[index];
        const char *role = px_get_str(message, "role");
        const char *content = px_get_str(message, "content");
        if (role != NULL && strcmp(role, "system") == 0) {
            if (content != NULL && starts_with(content, "[context compacted:")) {
                continue;
            }
            system[system_count++] = message;
        } else {
            rest[rest_count++] = message;
        }
    }
    size_t tokens = 0;
    for (size_t index = 0; index < system_count; index++) {
        const char *content = px_get_str(system[index], "content");
        tokens += 4 + (content == NULL ? 0 : strlen(content)) / 4;
    }
    if (tokens > max_tokens) {
        if (system_count == 0) {
            return check(!px_get_bool(expect, "ok", false), "expected failure");
        }
        size_t truncate = max_tokens > 4 ? max_tokens - 4 : 0;
        system[0] = clone_with_content(
            arena, system[0],
            truncate_tokens(arena, px_get_str(system[0], "content"), truncate));
        system_count = 1;
        tokens = 4 + strlen(px_get_str(system[0], "content")) / 4;
        if (tokens > max_tokens) {
            return check(!px_get_bool(expect, "ok", false), "expected failure");
        }
    }
    if (keep == 0) {
        keep = 4;
    }
    size_t start = rest_count > keep ? rest_count - keep : 0;
    while (start > 0) {
        const char *role = px_get_str(rest[start], "role");
        if (role != NULL && strcmp(role, "tool") == 0) {
            start--;
            continue;
        }
        break;
    }
    char marker_text[128];
    snprintf(marker_text, sizeof(marker_text),
             "[context compacted: %zu older messages omitted]", start);
    PxValue *marker = px_obj(arena);
    px_obj_set(arena, marker, "role", px_str(arena, "system"));
    px_obj_set(arena, marker, "content", px_str(arena, marker_text));
    PxValue **kept = rest + start;
    size_t kept_count = rest_count - start;
    PxValue *out = build_compacted(
        arena, system, system_count, marker, start > 0, kept, kept_count);
    while (estimate_tokens(arena, out) > max_tokens && kept_count > 1) {
        const char *role = px_get_str(kept[1], "role");
        if (role != NULL && strcmp(role, "tool") == 0) {
            break;
        }
        kept++;
        kept_count--;
        out = build_compacted(
            arena, system, system_count, marker, start > 0, kept, kept_count);
    }
    if (estimate_tokens(arena, out) > max_tokens) {
        return check(!px_get_bool(expect, "ok", false), "expected failure");
    }
    return check(px_equals(out, px_obj_get(expect, "messages")),
                 "messages mismatch");
}
