#include "toolcall.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

static bool is_space(char ch) {
    return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

static char *trim(char *text) {
    while (is_space(*text)) {
        text++;
    }
    char *end = text + strlen(text);
    while (end > text && is_space(end[-1])) {
        end--;
    }
    *end = '\0';
    return text;
}

static char *substring(PxArena *arena, const char *start, const char *end) {
    size_t size = (size_t)(end - start);
    char *out = px_arena_alloc(arena, size + 1);
    if (out == NULL) {
        return NULL;
    }
    memcpy(out, start, size);
    out[size] = '\0';
    return out;
}

static const char *find_last(const char *text, const char *needle) {
    const char *last = NULL;
    const char *cursor = text;
    while ((cursor = strstr(cursor, needle)) != NULL) {
        last = cursor;
        cursor += strlen(needle);
    }
    return last;
}

PxValue *px_parse_input_json(PxArena *arena, const char *raw) {
    if (raw == NULL) {
        return NULL;
    }
    char *copy = px_arena_strdup(arena, raw);
    PxValue *value = px_parse(arena, trim(copy));
    if (value != NULL && value->type == PX_OBJ) {
        return value;
    }
    size_t size = strlen(raw);
    char *escaped = px_arena_alloc(arena, size * 2 + 1);
    if (escaped == NULL) {
        return NULL;
    }
    size_t index = 0;
    for (size_t source = 0; source < size; source++) {
        if (raw[source] == '\\') {
            escaped[index++] = '\\';
        }
        escaped[index++] = raw[source];
    }
    escaped[index] = '\0';
    value = px_parse(arena, trim(escaped));
    return value != NULL && value->type == PX_OBJ ? value : NULL;
}

static PxToolCall *make_call(
    PxArena *arena, const char *name, PxValue *input) {
    PxToolCall *call = px_arena_alloc(arena, sizeof(PxToolCall));
    if (call == NULL) {
        return NULL;
    }
    call->name = px_arena_strdup(arena, name);
    call->input = input;
    return call;
}

static PxToolCall *parse_xml(PxArena *arena, const char *content) {
    const char *start = find_last(content, "<tool_call name=\"");
    if (start == NULL) {
        return NULL;
    }
    const char *name_start = start + strlen("<tool_call name=\"");
    const char *name_end = strchr(name_start, '"');
    if (name_end == NULL) {
        return NULL;
    }
    const char *body = strchr(name_end, '>');
    if (body == NULL) {
        return NULL;
    }
    const char *end = strstr(body, "</tool_call>");
    if (end == NULL) {
        return NULL;
    }
    char *name = substring(arena, name_start, name_end);
    PxValue *input = px_parse_input_json(
        arena, substring(arena, body + 1, end));
    if (input == NULL) {
        return NULL;
    }
    return make_call(arena, name, input);
}

static PxToolCall *parse_tag(PxArena *arena, const char *content) {
    const char *open = content;
    const char *name_start = NULL;
    const char *name_end = NULL;
    while ((open = strchr(open, '<')) != NULL) {
        const char *end = strchr(open, '>');
        if (open[1] != '/' && end != NULL) {
            char *candidate = substring(arena, open + 1, end);
            if (strchr(candidate, '.') != NULL) {
                name_start = open + 1;
                name_end = end;
            }
        }
        open++;
    }
    if (name_start == NULL) {
        return NULL;
    }
    const char *brace = strchr(name_end, '{');
    if (brace == NULL) {
        return NULL;
    }
    const char *end = strstr(brace, "</");
    if (end == NULL) {
        end = brace + strlen(brace);
    }
    char *name = substring(arena, name_start, name_end);
    PxValue *input = px_parse_input_json(arena, substring(arena, brace, end));
    if (input == NULL) {
        return NULL;
    }
    return make_call(arena, name, input);
}

static PxToolCall *parse_plain(PxArena *arena, const char *content) {
    char *copy = px_arena_strdup(arena, content);
    char *line = strtok(copy, "\n");
    while (line != NULL) {
        char *text = trim(line);
        char *space = strchr(text, ' ');
        if (space != NULL && strchr(text, '.') != NULL && space > text) {
            *space = '\0';
            PxValue *input = px_parse_input_json(arena, space + 1);
            if (input != NULL) {
                return make_call(arena, text, input);
            }
        }
        line = strtok(NULL, "\n");
    }
    return NULL;
}

PxToolCall *px_parse_toolcall(PxArena *arena, const char *content) {
    if (content == NULL) {
        return NULL;
    }
    PxValue *value = px_parse(arena, content);
    if (value != NULL && value->type == PX_OBJ
            && px_get_str(value, "name") != NULL) {
        PxValue *input = px_obj_get(value, "input");
        if (input == NULL || input->type != PX_OBJ) {
            input = px_obj(arena);
        }
        return make_call(arena, px_get_str(value, "name"), input);
    }
    PxToolCall *call = parse_xml(arena, content);
    if (call != NULL) {
        return call;
    }
    call = parse_tag(arena, content);
    if (call != NULL) {
        return call;
    }
    return parse_plain(arena, content);
}

char *px_strip_toolcall(PxArena *arena, const char *content) {
    char *out = px_arena_strdup(arena, content == NULL ? "" : content);
    while (true) {
        char *start = strstr(out, "<tool_call ");
        if (start == NULL) {
            break;
        }
        char *end = strstr(start, "</tool_call>");
        if (end == NULL) {
            *start = '\0';
            break;
        }
        memmove(start, end + strlen("</tool_call>"),
                strlen(end + strlen("</tool_call>")) + 1);
    }
    return trim(out);
}
