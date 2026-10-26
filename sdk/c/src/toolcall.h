#ifndef PX_TOOLCALL_H
#define PX_TOOLCALL_H

#include "praxo.h"

typedef struct {
    char *name;
    PxValue *input;
} PxToolCall;

PxToolCall *px_parse_toolcall(PxArena *arena, const char *content);
char *px_strip_toolcall(PxArena *arena, const char *content);
PxValue *px_parse_input_json(PxArena *arena, const char *raw);

#endif
