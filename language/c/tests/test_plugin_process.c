#include "praxo_plugin_process.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    const char *python = getenv("PYTHON");
    if (python == NULL || python[0] == '\0') python = "python";
    const char *fixture = "../tests/fixtures/process_plugin.py";
    FILE *probe = fopen(fixture, "rb");
    if (probe == NULL) {
        fixture = "language/c/tests/fixtures/process_plugin.py";
        probe = fopen(fixture, "rb");
    }
    if (probe != NULL) fclose(probe);
    const char *args[] = {fixture};
    PxPluginProcessConfig config = {
        .plugin_id = "com.example.echo",
        .path = python,
        .args = args,
        .arg_count = 1,
        .token = NULL,
        .start_timeout_ms = 5000,
        .invoke_timeout_ms = 2000,
    };
    const char *error = NULL;
    PxPluginProcess *host = px_plugin_process_start(&config, &error);
    if (host == NULL) fprintf(stderr, "start error: %s\\n", error == NULL ? "null" : error);
    assert(host != NULL);
    unsigned char *response = NULL;
    size_t response_length = 0;
    const char *payload = "{\"text\":\"hi\"}";
    int ok = px_plugin_process_invoke(host, "tool.provider", "echo",
        (const unsigned char *)payload, strlen(payload), &response,
        &response_length, &error);
    assert(ok);
    assert(response_length == strlen(payload));
    assert(memcmp(response, payload, response_length) == 0);
    free(response);
    response = NULL;
    error = NULL;
    ok = px_plugin_process_invoke(host, "tool.provider", "denied", NULL, 0,
        &response, &response_length, &error);
    assert(!ok && error != NULL && strcmp(error, "CAPABILITY_DENIED") == 0);
    ok = px_plugin_process_invoke(host, "tool.provider", "echo",
        (const unsigned char *)payload, strlen(payload), &response,
        &response_length, &error);
    assert(ok && response_length == strlen(payload));
    free(response);
    px_plugin_process_stop(host);
    px_plugin_process_stop(host);
    px_plugin_process_free(host);
    config.invoke_timeout_ms = 200;
    host = px_plugin_process_start(&config, &error);
    assert(host != NULL);
    response = NULL;
    error = NULL;
    ok = px_plugin_process_invoke(host, "tool.provider", "block", NULL, 0,
        &response, &response_length, &error);
    assert(!ok && error != NULL && strcmp(error, "TIMEOUT") == 0);
    ok = px_plugin_process_invoke(host, "tool.provider", "echo", NULL, 0,
        &response, &response_length, &error);
    assert(!ok && error != NULL && strcmp(error, "NOT_ACTIVE") == 0);
    px_plugin_process_free(host);
    const char *exit_args[] = {"-c", "raise SystemExit(0)"};
    config.args = exit_args;
    config.arg_count = 2;
    host = px_plugin_process_start(&config, &error);
    assert(host == NULL && error != NULL);
    config.path = "praxo-plugin-executable-that-does-not-exist";
    host = px_plugin_process_start(&config, &error);
    assert(host == NULL && error != NULL);
    px_plugin_process_stop(NULL);
    px_plugin_process_free(NULL);
    printf("C plugin process tests passed\n");
    return 0;
}
