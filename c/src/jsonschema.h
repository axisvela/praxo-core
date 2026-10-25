#ifndef PX_JSONSCHEMA_H
#define PX_JSONSCHEMA_H

#include "praxo.h"

void px_schema_validate(
    PxArena *arena,
    PxValue *schema,
    PxValue *data,
    const char *path,
    PxValue *errors);

#endif
