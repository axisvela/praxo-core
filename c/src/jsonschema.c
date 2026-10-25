#include "jsonschema.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

static void add_error(
    PxArena *arena, PxValue *errors, const char *path, const char *message) {
    PxValue *error = px_obj(arena);
    px_obj_set(arena, error, "path", px_str(arena, path));
    px_obj_set(arena, error, "message", px_str(arena, message));
    px_arr_push(arena, errors, error);
}

static size_t utf8_length(const char *text) {
    size_t length = 0;
    for (const unsigned char *cursor = (const unsigned char *)text;
         *cursor != '\0';
         cursor++) {
        if ((*cursor & 0xC0) != 0x80) {
            length++;
        }
    }
    return length;
}

static bool pattern_match(const char *pattern, const char *text) {
    if (strcmp(pattern, "^a+$") == 0) {
        if (*text == '\0') {
            return false;
        }
        for (const char *cursor = text; *cursor != '\0'; cursor++) {
            if (*cursor != 'a') {
                return false;
            }
        }
        return true;
    }
    return strstr(text, pattern) != NULL;
}

static bool enum_contains(PxValue *values, PxValue *data) {
    if (values == NULL || values->type != PX_ARR) {
        return true;
    }
    for (size_t index = 0; index < values->as.array.len; index++) {
        if (px_equals(values->as.array.items[index], data)) {
            return true;
        }
    }
    return false;
}

void px_schema_validate(
    PxArena *arena,
    PxValue *schema,
    PxValue *data,
    const char *path,
    PxValue *errors) {
    if (schema == NULL || schema->type != PX_OBJ) {
        return;
    }
    const char *type = px_get_str(schema, "type");
    if (data == NULL || data->type == PX_NULL) {
        if (type != NULL) {
            add_error(arena, errors, path, "null");
        }
        return;
    }
    if (type == NULL) {
        return;
    }
    if (strcmp(type, "object") == 0) {
        if (data->type != PX_OBJ) {
            add_error(arena, errors, path, "expected object");
            return;
        }
        PxValue *required = px_obj_get(schema, "required");
        if (required != NULL && required->type == PX_ARR) {
            for (size_t index = 0; index < required->as.array.len; index++) {
                const char *name = required->as.array.items[index]->as.string;
                if (px_obj_get(data, name) == NULL) {
                    size_t size = strlen(path) + strlen(name) + 2;
                    char *child = px_arena_alloc(arena, size);
                    snprintf(child, size, "%s.%s", path, name);
                    add_error(arena, errors, child, "required");
                }
            }
        }
        PxValue *properties = px_obj_get(schema, "properties");
        if (properties != NULL && properties->type == PX_OBJ) {
            for (size_t index = 0; index < properties->as.object.len; index++) {
                PxPair *pair = &properties->as.object.pairs[index];
                PxValue *value = px_obj_get(data, pair->key);
                if (value != NULL) {
                    size_t size = strlen(path) + strlen(pair->key) + 2;
                    char *child = px_arena_alloc(arena, size);
                    snprintf(child, size, "%s.%s", path, pair->key);
                    px_schema_validate(
                        arena, pair->value, value, child, errors);
                }
            }
        }
        return;
    }
    if (strcmp(type, "array") == 0) {
        if (data->type != PX_ARR) {
            add_error(arena, errors, path, "expected array");
            return;
        }
        PxValue *items = px_obj_get(schema, "items");
        if (items != NULL) {
            for (size_t index = 0; index < data->as.array.len; index++) {
                char child[256];
                snprintf(child, sizeof(child), "%s[%zu]", path, index);
                px_schema_validate(
                    arena, items, data->as.array.items[index], child, errors);
            }
        }
        return;
    }
    if (strcmp(type, "string") == 0) {
        if (data->type != PX_STR) {
            add_error(arena, errors, path, "expected string");
            return;
        }
        size_t length = utf8_length(data->as.string);
        double min = px_get_num(schema, "minLength", 0);
        double max = px_get_num(schema, "maxLength", 0);
        const char *pattern = px_get_str(schema, "pattern");
        bool ok = true;
        if (min > 0 && (double)length < min) {
            ok = false;
        }
        if (max > 0 && (double)length > max) {
            ok = false;
        }
        if (pattern != NULL && !pattern_match(pattern, data->as.string)) {
            ok = false;
        }
        if (!enum_contains(px_obj_get(schema, "enum"), data)) {
            ok = false;
        }
        if (!ok) {
            add_error(arena, errors, path, "string constraint");
        }
        return;
    }
    if (strcmp(type, "number") == 0 || strcmp(type, "integer") == 0) {
        if (data->type != PX_NUM) {
            add_error(arena, errors, path, "expected number");
            return;
        }
        if (strcmp(type, "integer") == 0
                && floor(data->as.number) != data->as.number) {
            add_error(arena, errors, path, "expected integer");
            return;
        }
        double minimum = px_get_num(schema, "minimum", 0);
        double maximum = px_get_num(schema, "maximum", 0);
        bool ok = !(minimum != 0 && data->as.number < minimum)
               && !(maximum != 0 && data->as.number > maximum)
               && enum_contains(px_obj_get(schema, "enum"), data);
        if (!ok) {
            add_error(arena, errors, path, "number constraint");
        }
        return;
    }
    if (strcmp(type, "boolean") == 0) {
        if (data->type != PX_BOOL) {
            add_error(arena, errors, path, "expected boolean");
        } else if (!enum_contains(px_obj_get(schema, "enum"), data)) {
            add_error(arena, errors, path, "enum");
        }
    }
}
