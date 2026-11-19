#ifndef PRAXO_PLUGIN_PROCESS_H
#define PRAXO_PLUGIN_PROCESS_H

#include <stddef.h>

typedef struct PxPluginProcess PxPluginProcess;

typedef struct {
    const char *plugin_id;
    const char *path;
    const char *const *args;
    int arg_count;
    const char *token;
    int start_timeout_ms;
    int invoke_timeout_ms;
} PxPluginProcessConfig;

PxPluginProcess *px_plugin_process_start(const PxPluginProcessConfig *config,
    const char **error);
int px_plugin_process_invoke(PxPluginProcess *host, const char *service,
    const char *method, const unsigned char *payload, size_t payload_length,
    unsigned char **response, size_t *response_length, const char **error);
void px_plugin_process_stop(PxPluginProcess *host);
void px_plugin_process_free(PxPluginProcess *host);

#endif
