#ifndef PX_VECTORS_AGENT_H
#define PX_VECTORS_AGENT_H

#include "praxo.h"

bool px_run_middleware(PxArena *arena, PxValue *input, PxValue *expect);
bool px_run_agent_loop(PxArena *arena, PxValue *input, PxValue *expect);

#endif
