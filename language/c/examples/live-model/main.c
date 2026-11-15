#include "praxo_core.h"
#include "openai.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    PxOpenAICompatible adapter;
    int model_calls;
    int tool_calls;
} LiveState;

static const char *env_or(const char *name, const char *fallback) {
    const char *value = getenv(name);
    return value != NULL && value[0] != '\0' ? value : fallback;
}

static PxValue *live_tools(PxArena *arena) {
    PxValue *tools = px_arr(arena);
    PxValue *tool = px_obj(arena);
    px_obj_set(arena, tool, "name", px_str(arena, "get_time"));
    px_obj_set(arena, tool, "description", px_str(arena,
        "Return the current time in ISO 8601 format for the requested zone."));
    px_obj_set(arena, tool, "parameters", px_parse(arena,
        "{\"type\":\"object\",\"properties\":{\"zone\":{\"type\":\"string\","
        "\"enum\":[\"utc\",\"local\"],"
        "\"description\":\"utc or local; defaults to utc\"}}}"));
    px_obj_set(arena, tool, "risk", px_str(arena, "read"));
    px_arr_push(arena, tools, tool);
    return tools;
}

static PxValue *live_generate(PxArena *arena, PxValue *messages,
        PxValue *tools, void *ctx) {
    (void)tools;
    LiveState *state = ctx;
    state->model_calls++;
    return px_openai_generate(arena, messages, live_tools(arena),
        &state->adapter);
}

static PxValue *get_time(PxArena *arena, const char *name,
        PxValue *arguments, void *ctx) {
    LiveState *state = ctx;
    if (name == NULL || strcmp(name, "get_time") != 0) {
        return NULL;
    }
    state->tool_calls++;
    const char *zone = arguments == NULL ? NULL
        : px_get_str(arguments, "zone");
    time_t now = time(NULL);
    struct tm value;
    int local = zone != NULL && strcmp(zone, "local") == 0;
    if (local) {
        value = *localtime(&now);
    } else {
        value = *gmtime(&now);
    }
    char text[64];
    if (local) {
        strftime(text, sizeof(text), "%Y-%m-%dT%H:%M:%S", &value);
    } else {
        strftime(text, sizeof(text), "%Y-%m-%dT%H:%M:%SZ", &value);
    }
    return px_str(arena, text);
}

static const char *authorize(const char *kind, const char *session_id,
        const char *tool_name, PxValue *arguments, void *ctx) {
    (void)session_id;
    (void)arguments;
    (void)ctx;
    if (strcmp(kind, "model.generate") == 0) {
        return NULL;
    }
    if (strcmp(kind, "tool.invoke") == 0 && tool_name != NULL
            && strcmp(tool_name, "get_time") == 0) {
        return NULL;
    }
    return "AGENT_POLICY_DENIED";
}

static const char *missing_transport(const char *url, const char *body,
        const char *api_key, void *ctx, const char **error) {
    (void)url;
    (void)body;
    (void)api_key;
    (void)ctx;
    if (error != NULL) {
        *error = "PROVIDER_HTTP";
    }
    return NULL;
}

static const char *allowed_tools[] = {"get_time"};

int main(void) {
    const char *base_url = env_or("PRAXO_BASE_URL",
        "http://localhost:11434/v1");
    const char *model_name = env_or("PRAXO_MODEL", "qwen3.5:4b");
    const char *api_key = env_or("PRAXO_API_KEY", "");
    const char *prompt = env_or("PRAXO_PROMPT",
        "What time is it? Use get_time with zone set to utc and reply with the time.");

    LiveState state;
    memset(&state, 0, sizeof(state));
    state.adapter.base_url = base_url;
    state.adapter.model = model_name;
    state.adapter.api_key = api_key;
    state.adapter.transport = missing_transport;
    state.adapter.transport_ctx = NULL;

    PxArena arena;
    px_arena_init(&arena);
    PxValue *session = px_arr(&arena);
    PxValue *system = px_obj(&arena);
    px_obj_set(&arena, system, "role", px_str(&arena, "system"));
    px_obj_set(&arena, system, "content", px_str(&arena,
        "You are a concise assistant. Use the provided tools when they help."));
    px_arr_push(&arena, session, system);

    PxAgentOptions options = {
        .generate = live_generate,
        .invoke = get_time,
        .ctx = &state,
        .max_steps = 4,
        .authorize = authorize,
        .allowed_tools = allowed_tools,
        .allowed_tools_count = 1,
    };
    PxAgentResult result;
    const char *error = px_agent_run(&arena, &options, session, prompt, &result);
    if (error != NULL) {
        fprintf(stderr,
            "live model run failed: %s\n\n"
            "Check PRAXO_BASE_URL (%s), PRAXO_MODEL (%s), and PRAXO_API_KEY.\n"
            "The C Core bundles no HTTP client; supply a caller-owned\n"
            "PxOpenAITransport in examples/live-model/main.c.\n",
            error, base_url, model_name);
        px_arena_free(&arena);
        return 1;
    }
    printf("%s\n", result.output);
    px_arena_free(&arena);
    return 0;
}
