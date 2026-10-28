#include "praxo_core.h"

#include <stdio.h>
#include <string.h>

int px_estimate_tokens(const PxContextMessage *messages, size_t count) {
    int total = 0;
    for (size_t index = 0; index < count; index++) {
        total += 4 + (int)(strlen(messages[index].content) / 4);
    }
    return total;
}

PxValue *px_message_wire(PxArena *arena, const PxContextMessage *message) {
    PxValue *object = px_obj(arena);
    px_obj_set(arena, object, "role", px_str(arena, message->role));
    px_obj_set(arena, object, "content", px_str(arena, message->content));
    return object;
}

static bool is_system(const PxContextMessage *message) {
    return strcmp(message->role, "system") == 0;
}

static bool is_marker(const PxContextMessage *message) {
    return strncmp(message->content, "[context compacted:", 19) == 0;
}

bool px_compact_context(PxArena *arena, const PxContextBudget *budget,
        const PxContextMessage *messages, size_t count,
        PxContextMessage **out, size_t *out_count) {
    if (budget->max_tokens <= 0 || px_estimate_tokens(messages, count) <= budget->max_tokens) {
        PxContextMessage *copy = px_arena_alloc(arena, sizeof(PxContextMessage) * (count + 1));
        memcpy(copy, messages, sizeof(PxContextMessage) * count);
        *out = copy;
        *out_count = count;
        return true;
    }
    PxContextMessage *system = px_arena_alloc(arena, sizeof(PxContextMessage) * (count + 1));
    PxContextMessage *rest = px_arena_alloc(arena, sizeof(PxContextMessage) * (count + 1));
    size_t system_count = 0;
    size_t rest_count = 0;
    for (size_t index = 0; index < count; index++) {
        if (is_system(&messages[index])) {
            if (!is_marker(&messages[index])) {
                system[system_count++] = messages[index];
            }
        } else {
            rest[rest_count++] = messages[index];
        }
    }
    if (px_estimate_tokens(system, system_count) > budget->max_tokens) {
        if (system_count == 0) {
            return false;
        }
        size_t limit = budget->max_tokens > 4 ? (size_t)(budget->max_tokens - 4) * 4 : 0;
        if (strlen(system[0].content) > limit) {
            char *trimmed = px_arena_alloc(arena, limit + 1);
            memcpy(trimmed, system[0].content, limit);
            trimmed[limit] = '\0';
            system[0].content = trimmed;
        }
        system_count = 1;
        if (px_estimate_tokens(system, system_count) > budget->max_tokens) {
            return false;
        }
    }
    size_t keep = budget->keep_recent > 0 ? (size_t)budget->keep_recent : 4;
    size_t start = rest_count > keep ? rest_count - keep : 0;
    while (start > 0 && strcmp(rest[start].role, "tool") == 0) {
        start--;
    }
    PxContextMessage marker;
    marker.role = "system";
    char buffer[128];
    snprintf(buffer, sizeof(buffer), "[context compacted: %zu older messages omitted]", start);
    marker.content = px_arena_strdup(arena, buffer);
    size_t kept = rest_count - start;
    PxContextMessage *output = px_arena_alloc(arena,
        sizeof(PxContextMessage) * (system_count + 1 + kept + 1));
    size_t written = 0;
    for (size_t index = 0; index < system_count; index++) {
        output[written++] = system[index];
    }
    if (start > 0) {
        output[written++] = marker;
    }
    for (size_t index = start; index < rest_count; index++) {
        output[written++] = rest[index];
    }
    while (px_estimate_tokens(output, written) > budget->max_tokens && kept > 1) {
        size_t marker_offset = system_count + (start > 0 ? 1 : 0);
        if (marker_offset + 1 < written && strcmp(output[marker_offset + 1].role, "tool") == 0) {
            return false;
        }
        memmove(&output[marker_offset], &output[marker_offset + 1],
            sizeof(PxContextMessage) * (written - marker_offset - 1));
        written--;
        kept--;
    }
    *out = output;
    *out_count = written;
    return px_estimate_tokens(output, written) <= budget->max_tokens;
}
