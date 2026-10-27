#ifndef PRAXO_CORE_H
#define PRAXO_CORE_H

#include <stdbool.h>
#include <stddef.h>

#include "praxo.h"

#define PRAXO_CORE_VERSION "0.2.0"

typedef struct {
    const char *session;
    const char *id;
    const char *frame;
    const char *content;
    const char *created_at;
} PxMemoryRecord;

typedef struct {
    PxMemoryRecord *records;
    size_t len;
    int sequence;
} PxMemoryStore;

void px_memory_init(PxMemoryStore *store);
bool px_memory_put(PxArena *arena, PxMemoryStore *store, const char *session,
    const char *id, const char *frame, const char *content,
    const char *created_at, PxMemoryRecord *out);
size_t px_memory_search(PxArena *arena, const PxMemoryStore *store,
    const char *session, const char *query, int limit, PxMemoryRecord **out);

typedef struct {
    const char *kind;
    const char *session_id;
    const char *run_id;
    PxValue *data;
} PxEvent;

typedef struct PxSink PxSink;

PxSink *px_sink_new(PxArena *arena);
PxSink *px_sink_multi(PxArena *arena, PxSink **sinks, size_t count);
PxSink *px_sink_filter(PxArena *arena, PxSink *target,
    const char **predicate, size_t count);
void px_sink_emit(PxSink *sink, const PxEvent *event);
size_t px_sink_kinds(const PxSink *sink, const char ***out);
size_t px_sink_child_count(const PxSink *sink);
const PxSink *px_sink_child(const PxSink *sink, size_t index);

typedef struct {
    const char **kinds;
    size_t len;
} PxAllowlist;

void px_checkpoint_init(PxAllowlist *allow);
bool px_checkpoint_register(PxArena *arena, PxAllowlist *allow,
    const char *kind);
const char *px_checkpoint_marshal(PxArena *arena, const PxAllowlist *allow,
    const char *kind, PxValue *value, char **out);
const char *px_checkpoint_unmarshal(PxArena *arena, const PxAllowlist *allow,
    const char *data, PxValue **out);

typedef struct {
    const char *root;
    const char *access;
} PxPathGrant;

typedef struct {
    PxPathGrant *grants;
    size_t len;
} PxPathChecker;

typedef struct {
    bool allowed;
    const char *reason;
} PxDecision;

const char *px_normalize_path(PxArena *arena, const char *value, char **out);
bool px_path_checker(PxArena *arena, const PxPathGrant *grants, size_t count,
    PxPathChecker *checker, const char **code);
bool px_path_check(PxArena *arena, const PxPathChecker *checker,
    const char *target, const char *need, PxDecision *decision,
    const char **code);
bool px_path_allowed(PxArena *arena, const PxPathChecker *checker,
    const char *target, const char *need);

typedef struct {
    const char *role;
    const char *content;
} PxContextMessage;

typedef struct {
    int max_tokens;
    int keep_recent;
} PxContextBudget;

int px_estimate_tokens(const PxContextMessage *messages, size_t count);
bool px_compact_context(PxArena *arena, const PxContextBudget *budget,
    const PxContextMessage *messages, size_t count,
    PxContextMessage **out, size_t *out_count);
PxValue *px_message_wire(PxArena *arena, const PxContextMessage *message);

char *px_pii_redact(PxArena *arena, const char *text);
PxValue *px_redact_value(PxArena *arena, PxValue *value);
PxValue *px_extract_json(PxArena *arena, const char *text);

typedef char *(*PxRepairer)(PxArena *arena, const char *text, void *ctx);

typedef struct {
    PxValue *schema;
    int max_repairs;
    PxRepairer repairer;
    void *ctx;
} PxStructuredOutput;

char *px_apply_structured(PxArena *arena, const PxStructuredOutput *config,
    const char *text);

typedef struct {
    int model_limit;
    int tool_limit;
    int models;
    int tools;
} PxCallLimit;

void px_call_limit_init(PxCallLimit *limit, int model_limit, int tool_limit);
const char *px_call_limit_model(PxCallLimit *limit);
const char *px_call_limit_tool(PxCallLimit *limit);

size_t px_stream_kinds(const char ***out);
const char *px_fallback(const char *primary, const char *fallback,
    bool primary_failed);

size_t px_select_tools(PxArena *arena, const char **selection,
    size_t selection_count, const char **tools, size_t tool_count,
    const char ***out);
const char *px_check_tool_selected(const char **selection,
    size_t selection_count, const char *name);

typedef struct {
    PxValue *(*generate)(PxArena *arena, PxValue *messages, PxValue *tools,
        void *ctx);
    PxValue *(*invoke)(PxArena *arena, const char *name, PxValue *arguments,
        void *ctx);
    void (*emit)(const char *kind, void *ctx);
    void *ctx;
    int max_steps;
    long max_tokens;
} PxAgentOptions;

typedef struct {
    const char *output;
    int steps;
    long input_tokens;
    long output_tokens;
} PxAgentResult;

const char *px_agent_run(PxArena *arena, const PxAgentOptions *options,
    PxValue *session_messages, const char *prompt, PxAgentResult *result);

#endif
