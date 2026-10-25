#include "praxo.h"

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct PxArenaBlock {
    struct PxArenaBlock *next;
    size_t used;
    size_t cap;
    unsigned char data[];
};

#define PX_ARENA_BLOCK 4096
#define PX_ALIGN 16

void px_arena_init(PxArena *arena) {
    arena->head = NULL;
}

void *px_arena_alloc(PxArena *arena, size_t size) {
    size = (size + PX_ALIGN - 1) & ~(size_t)(PX_ALIGN - 1);
    if (size == 0) {
        size = PX_ALIGN;
    }
    if (arena->head == NULL || arena->head->cap - arena->head->used < size) {
        size_t cap = size > PX_ARENA_BLOCK ? size : PX_ARENA_BLOCK;
        struct PxArenaBlock *block =
            calloc(1, sizeof(struct PxArenaBlock) + cap);
        if (block == NULL) {
            return NULL;
        }
        block->cap = cap;
        block->next = arena->head;
        arena->head = block;
    }
    void *result = arena->head->data + arena->head->used;
    arena->head->used += size;
    return result;
}

char *px_arena_strdup(PxArena *arena, const char *text) {
    size_t size = text == NULL ? 0 : strlen(text);
    char *out = px_arena_alloc(arena, size + 1);
    if (out == NULL) {
        return NULL;
    }
    if (size > 0) {
        memcpy(out, text, size);
    }
    out[size] = '\0';
    return out;
}

void px_arena_free(PxArena *arena) {
    struct PxArenaBlock *block = arena->head;
    while (block != NULL) {
        struct PxArenaBlock *next = block->next;
        free(block);
        block = next;
    }
    arena->head = NULL;
}

static PxValue *value_new(PxArena *arena, PxType type) {
    PxValue *value = px_arena_alloc(arena, sizeof(PxValue));
    if (value == NULL) {
        return NULL;
    }
    memset(value, 0, sizeof(PxValue));
    value->type = type;
    return value;
}

PxValue *px_null(PxArena *arena) {
    return value_new(arena, PX_NULL);
}

PxValue *px_bool(PxArena *arena, bool input) {
    PxValue *value = value_new(arena, PX_BOOL);
    if (value != NULL) {
        value->as.boolean = input;
    }
    return value;
}

PxValue *px_num(PxArena *arena, double input) {
    PxValue *value = value_new(arena, PX_NUM);
    if (value != NULL) {
        value->as.number = input;
    }
    return value;
}

PxValue *px_str(PxArena *arena, const char *input) {
    PxValue *value = value_new(arena, PX_STR);
    if (value != NULL) {
        value->as.string = px_arena_strdup(arena, input == NULL ? "" : input);
    }
    return value;
}

PxValue *px_arr(PxArena *arena) {
    return value_new(arena, PX_ARR);
}

PxValue *px_obj(PxArena *arena) {
    return value_new(arena, PX_OBJ);
}

void px_arr_push(PxArena *arena, PxValue *array, PxValue *item) {
    if (array == NULL || array->type != PX_ARR) {
        return;
    }
    PxValue **items =
        px_arena_alloc(arena, sizeof(PxValue *) * (array->as.array.len + 1));
    if (items == NULL) {
        return;
    }
    if (array->as.array.len > 0) {
        memcpy(items, array->as.array.items,
               sizeof(PxValue *) * array->as.array.len);
    }
    items[array->as.array.len] = item;
    array->as.array.items = items;
    array->as.array.len += 1;
}

void px_obj_set(PxArena *arena, PxValue *object, const char *key, PxValue *value) {
    if (object == NULL || object->type != PX_OBJ) {
        return;
    }
    for (size_t index = 0; index < object->as.object.len; index++) {
        if (strcmp(object->as.object.pairs[index].key, key) == 0) {
            object->as.object.pairs[index].value = value;
            return;
        }
    }
    PxPair *pairs =
        px_arena_alloc(arena, sizeof(PxPair) * (object->as.object.len + 1));
    if (pairs == NULL) {
        return;
    }
    if (object->as.object.len > 0) {
        memcpy(pairs, object->as.object.pairs,
               sizeof(PxPair) * object->as.object.len);
    }
    pairs[object->as.object.len].key = px_arena_strdup(arena, key);
    pairs[object->as.object.len].value = value;
    object->as.object.pairs = pairs;
    object->as.object.len += 1;
}

PxValue *px_obj_get(const PxValue *object, const char *key) {
    if (object == NULL || object->type != PX_OBJ) {
        return NULL;
    }
    for (size_t index = 0; index < object->as.object.len; index++) {
        if (strcmp(object->as.object.pairs[index].key, key) == 0) {
            return object->as.object.pairs[index].value;
        }
    }
    return NULL;
}

const char *px_get_str(const PxValue *object, const char *key) {
    PxValue *value = px_obj_get(object, key);
    return value != NULL && value->type == PX_STR ? value->as.string : NULL;
}

double px_get_num(const PxValue *object, const char *key, double fallback) {
    PxValue *value = px_obj_get(object, key);
    return value != NULL && value->type == PX_NUM ? value->as.number : fallback;
}

bool px_get_bool(const PxValue *object, const char *key, bool fallback) {
    PxValue *value = px_obj_get(object, key);
    return value != NULL && value->type == PX_BOOL ? value->as.boolean : fallback;
}

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} Buffer;

static void buffer_init(Buffer *buffer) {
    buffer->data = NULL;
    buffer->len = 0;
    buffer->cap = 0;
}

static void buffer_append(Buffer *buffer, const char *text) {
    size_t size = strlen(text);
    if (buffer->len + size + 1 > buffer->cap) {
        size_t cap = buffer->cap == 0 ? 128 : buffer->cap;
        while (cap < buffer->len + size + 1) {
            cap *= 2;
        }
        char *data = realloc(buffer->data, cap);
        if (data == NULL) {
            return;
        }
        buffer->data = data;
        buffer->cap = cap;
    }
    memcpy(buffer->data + buffer->len, text, size);
    buffer->len += size;
    buffer->data[buffer->len] = '\0';
}

static void stringify(Buffer *buffer, const PxValue *value) {
    if (value == NULL) {
        buffer_append(buffer, "null");
        return;
    }
    switch (value->type) {
        case PX_NULL:
            buffer_append(buffer, "null");
            break;
        case PX_BOOL:
            buffer_append(buffer, value->as.boolean ? "true" : "false");
            break;
        case PX_NUM: {
            char text[64];
            double number = value->as.number;
            if (isfinite(number) && floor(number) == number && fabs(number) < 1e15) {
                snprintf(text, sizeof(text), "%.0f", number);
            } else {
                snprintf(text, sizeof(text), "%.17g", number);
            }
            buffer_append(buffer, text);
            break;
        }
        case PX_STR: {
            buffer_append(buffer, "\"");
            for (const char *cursor = value->as.string; *cursor != '\0'; cursor++) {
                char text[8];
                switch (*cursor) {
                    case '"':
                        buffer_append(buffer, "\\\"");
                        break;
                    case '\\':
                        buffer_append(buffer, "\\\\");
                        break;
                    case '\n':
                        buffer_append(buffer, "\\n");
                        break;
                    case '\r':
                        buffer_append(buffer, "\\r");
                        break;
                    case '\t':
                        buffer_append(buffer, "\\t");
                        break;
                    default:
                        if ((unsigned char)*cursor < 0x20) {
                            snprintf(text, sizeof(text), "\\u%04x",
                                     (unsigned char)*cursor);
                            buffer_append(buffer, text);
                        } else {
                            text[0] = *cursor;
                            text[1] = '\0';
                            buffer_append(buffer, text);
                        }
                        break;
                }
            }
            buffer_append(buffer, "\"");
            break;
        }
        case PX_ARR:
            buffer_append(buffer, "[");
            for (size_t index = 0; index < value->as.array.len; index++) {
                if (index > 0) {
                    buffer_append(buffer, ",");
                }
                stringify(buffer, value->as.array.items[index]);
            }
            buffer_append(buffer, "]");
            break;
        case PX_OBJ:
            buffer_append(buffer, "{");
            for (size_t index = 0; index < value->as.object.len; index++) {
                if (index > 0) {
                    buffer_append(buffer, ",");
                }
                buffer_append(buffer, "\"");
                buffer_append(buffer, value->as.object.pairs[index].key);
                buffer_append(buffer, "\":");
                stringify(buffer, value->as.object.pairs[index].value);
            }
            buffer_append(buffer, "}");
            break;
    }
}

char *px_stringify(PxArena *arena, const PxValue *value) {
    Buffer buffer;
    buffer_init(&buffer);
    stringify(&buffer, value);
    char *out = px_arena_strdup(arena, buffer.data == NULL ? "" : buffer.data);
    free(buffer.data);
    return out;
}

typedef struct {
    PxArena *arena;
    const char *text;
    size_t index;
} Parser;

static void parser_ws(Parser *parser) {
    while (parser->text[parser->index] != '\0' &&
           isspace((unsigned char)parser->text[parser->index])) {
        parser->index += 1;
    }
}

static PxValue *parser_value(Parser *parser);

static PxValue *parser_string(Parser *parser) {
    if (parser->text[parser->index] != '"') {
        return NULL;
    }
    parser->index += 1;
    size_t cap = strlen(parser->text) + 1;
    char *out = px_arena_alloc(parser->arena, cap);
    if (out == NULL) {
        return NULL;
    }
    size_t len = 0;
    while (parser->text[parser->index] != '\0') {
        char ch = parser->text[parser->index++];
        if (ch == '"') {
            out[len] = '\0';
            return px_str(parser->arena, out);
        }
        if (ch != '\\') {
            out[len++] = ch;
            continue;
        }
        char escape = parser->text[parser->index++];
        switch (escape) {
            case '"':
            case '\\':
            case '/':
                out[len++] = escape;
                break;
            case 'b':
                out[len++] = '\b';
                break;
            case 'f':
                out[len++] = '\f';
                break;
            case 'n':
                out[len++] = '\n';
                break;
            case 'r':
                out[len++] = '\r';
                break;
            case 't':
                out[len++] = '\t';
                break;
            case 'u': {
                char hex[5] = {0};
                for (int index = 0; index < 4; index++) {
                    hex[index] = parser->text[parser->index + (size_t)index];
                }
                parser->index += 4;
                out[len++] = (char)strtol(hex, NULL, 16);
                break;
            }
            default:
                return NULL;
        }
    }
    return NULL;
}

static PxValue *parser_number(Parser *parser) {
    const char *start = parser->text + parser->index;
    char *end = NULL;
    double number = strtod(start, &end);
    if (end == start) {
        return NULL;
    }
    parser->index += (size_t)(end - start);
    return px_num(parser->arena, number);
}

static PxValue *parser_array(Parser *parser) {
    parser->index += 1;
    PxValue *array = px_arr(parser->arena);
    parser_ws(parser);
    if (parser->text[parser->index] == ']') {
        parser->index += 1;
        return array;
    }
    while (true) {
        PxValue *value = parser_value(parser);
        if (value == NULL) {
            return NULL;
        }
        px_arr_push(parser->arena, array, value);
        parser_ws(parser);
        if (parser->text[parser->index] == ',') {
            parser->index += 1;
            continue;
        }
        if (parser->text[parser->index] == ']') {
            parser->index += 1;
            return array;
        }
        return NULL;
    }
}

static PxValue *parser_object(Parser *parser) {
    parser->index += 1;
    PxValue *object = px_obj(parser->arena);
    parser_ws(parser);
    if (parser->text[parser->index] == '}') {
        parser->index += 1;
        return object;
    }
    while (true) {
        parser_ws(parser);
        PxValue *key = parser_string(parser);
        if (key == NULL) {
            return NULL;
        }
        parser_ws(parser);
        if (parser->text[parser->index] != ':') {
            return NULL;
        }
        parser->index += 1;
        PxValue *value = parser_value(parser);
        if (value == NULL) {
            return NULL;
        }
        px_obj_set(parser->arena, object, key->as.string, value);
        parser_ws(parser);
        if (parser->text[parser->index] == ',') {
            parser->index += 1;
            continue;
        }
        if (parser->text[parser->index] == '}') {
            parser->index += 1;
            return object;
        }
        return NULL;
    }
}

static PxValue *parser_value(Parser *parser) {
    parser_ws(parser);
    char ch = parser->text[parser->index];
    if (ch == '{') {
        return parser_object(parser);
    }
    if (ch == '[') {
        return parser_array(parser);
    }
    if (ch == '"') {
        return parser_string(parser);
    }
    if (ch == 't' && strncmp(parser->text + parser->index, "true", 4) == 0) {
        parser->index += 4;
        return px_bool(parser->arena, true);
    }
    if (ch == 'f' && strncmp(parser->text + parser->index, "false", 5) == 0) {
        parser->index += 5;
        return px_bool(parser->arena, false);
    }
    if (ch == 'n' && strncmp(parser->text + parser->index, "null", 4) == 0) {
        parser->index += 4;
        return px_null(parser->arena);
    }
    return parser_number(parser);
}

PxValue *px_parse(PxArena *arena, const char *text) {
    if (text == NULL) {
        return NULL;
    }
    Parser parser = {arena, text, 0};
    PxValue *value = parser_value(&parser);
    if (value == NULL) {
        return NULL;
    }
    parser_ws(&parser);
    if (parser.text[parser.index] != '\0') {
        return NULL;
    }
    return value;
}
