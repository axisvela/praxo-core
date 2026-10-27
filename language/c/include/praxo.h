#ifndef PRAXO_H
#define PRAXO_H

#include <stdbool.h>
#include <stddef.h>

#define PRAXO_SDK_VERSION "0.2.0"
#define PRAXO_SPEC_VERSION "0.2.0"

typedef struct PxArenaBlock PxArenaBlock;

typedef struct {
    PxArenaBlock *head;
} PxArena;

void px_arena_init(PxArena *arena);
void *px_arena_alloc(PxArena *arena, size_t size);
char *px_arena_strdup(PxArena *arena, const char *text);
void px_arena_free(PxArena *arena);

typedef enum {
    PX_NULL,
    PX_BOOL,
    PX_NUM,
    PX_STR,
    PX_ARR,
    PX_OBJ
} PxType;

typedef struct PxValue PxValue;

typedef struct {
    char *key;
    PxValue *value;
} PxPair;

struct PxValue {
    PxType type;
    union {
        bool boolean;
        double number;
        char *string;
        struct {
            PxValue **items;
            size_t len;
        } array;
        struct {
            PxPair *pairs;
            size_t len;
        } object;
    } as;
};

PxValue *px_null(PxArena *arena);
PxValue *px_bool(PxArena *arena, bool value);
PxValue *px_num(PxArena *arena, double value);
PxValue *px_str(PxArena *arena, const char *value);
PxValue *px_arr(PxArena *arena);
PxValue *px_obj(PxArena *arena);

void px_arr_push(PxArena *arena, PxValue *array, PxValue *item);
void px_obj_set(PxArena *arena, PxValue *object, const char *key, PxValue *value);
PxValue *px_obj_get(const PxValue *object, const char *key);
const char *px_get_str(const PxValue *object, const char *key);
double px_get_num(const PxValue *object, const char *key, double fallback);
bool px_get_bool(const PxValue *object, const char *key, bool fallback);
bool px_equals(const PxValue *left, const PxValue *right);
char *px_stringify(PxArena *arena, const PxValue *value);
PxValue *px_parse(PxArena *arena, const char *text);

char *px_read_file(const char *path);
char *px_repo_root(void);

#endif
