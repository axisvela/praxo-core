#include "praxo_plugin_process.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#include "praxo.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#define PX_PLUGIN_TOKEN_ENV "PRAXOVELA_PLUGIN_TOKEN"
#define PX_PLUGIN_FRAME_MAX 262144
#define PX_PLUGIN_B64 \
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

struct PxPluginProcess {
    char *plugin_id;
    char *token;
    char *buffer;
    size_t buffer_length;
    unsigned long long sequence;
    int active;
    int invoke_timeout_ms;
#ifdef _WIN32
    HANDLE process;
    HANDLE input;
    HANDLE output;
#else
    int pid;
    int input;
    int output;
#endif
};

static void px_error(const char **error, const char *code) {
    if (error != NULL) *error = code;
}

static char *px_copy(const char *value) {
    size_t length = value == NULL ? 0 : strlen(value);
    char *copy = malloc(length + 1);
    if (copy != NULL) {
        if (length > 0) memcpy(copy, value, length);
        copy[length] = '\0';
    }
    return copy;
}

static char *px_b64_encode(const unsigned char *data, size_t length) {
    size_t output_length = ((length + 2) / 3) * 4 + 1;
    char *output = malloc(output_length);
    if (output == NULL) return NULL;
    size_t source = 0;
    size_t target = 0;
    while (source < length) {
        size_t remaining = length - source;
        unsigned int a = data[source];
        unsigned int b = remaining > 1 ? data[source + 1] : 0;
        unsigned int c = remaining > 2 ? data[source + 2] : 0;
        output[target++] = PX_PLUGIN_B64[a >> 2];
        output[target++] = PX_PLUGIN_B64[((a & 3) << 4) | (b >> 4)];
        output[target++] = remaining > 1
            ? PX_PLUGIN_B64[((b & 15) << 2) | (c >> 6)] : '=';
        output[target++] = remaining > 2 ? PX_PLUGIN_B64[c & 63] : '=';
        source += 3;
    }
    output[target] = '\0';
    return output;
}

static unsigned char *px_b64_decode(const char *text, size_t *length) {
    size_t input_length = strlen(text);
    unsigned char *output = malloc(input_length / 4 * 3 + 3);
    if (output == NULL) return NULL;
    unsigned int buffer = 0;
    int bits = 0;
    size_t count = 0;
    for (size_t index = 0; index < input_length; index++) {
        if (text[index] == '=') break;
        const char *position = strchr(PX_PLUGIN_B64, text[index]);
        if (position == NULL) {
            free(output);
            return NULL;
        }
        buffer = (buffer << 6) | (unsigned int)(position - PX_PLUGIN_B64);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            output[count++] = (unsigned char)((buffer >> bits) & 0xff);
        }
    }
    *length = count;
    return output;
}

static int px_escape(char **cursor, const char *end, const char *value) {
    if (value == NULL) value = "";
    for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
        if (*cursor + 8 >= end) return 0;
        switch (*p) {
        case '"': *(*cursor)++ = '\\'; *(*cursor)++ = '"'; break;
        case '\\': *(*cursor)++ = '\\'; *(*cursor)++ = '\\'; break;
        case '\n': *(*cursor)++ = '\\'; *(*cursor)++ = 'n'; break;
        case '\r': *(*cursor)++ = '\\'; *(*cursor)++ = 'r'; break;
        case '\t': *(*cursor)++ = '\\'; *(*cursor)++ = 't'; break;
        default:
            if (*p < 0x20)
                (*cursor) += snprintf(*cursor, (size_t)(end - *cursor),
                    "\\u%04x", *p);
            else
                *(*cursor)++ = (char)*p;
            break;
        }
    }
    return 1;
}

#ifdef _WIN32

static char *px_environment(const char *token) {
    char *source = GetEnvironmentStringsA();
    if (source == NULL) return NULL;
    size_t total = 1;
    for (char *p = source; *p != '\0'; p += strlen(p) + 1) {
        if (strncmp(p, PX_PLUGIN_TOKEN_ENV "=",
                strlen(PX_PLUGIN_TOKEN_ENV) + 1) == 0)
            continue;
        total += strlen(p) + 1;
    }
    total += strlen(PX_PLUGIN_TOKEN_ENV) + strlen(token) + 2;
    char *block = malloc(total);
    if (block == NULL) {
        FreeEnvironmentStringsA(source);
        return NULL;
    }
    char *target = block;
    for (char *p = source; *p != '\0'; p += strlen(p) + 1) {
        if (strncmp(p, PX_PLUGIN_TOKEN_ENV "=",
                strlen(PX_PLUGIN_TOKEN_ENV) + 1) == 0)
            continue;
        size_t length = strlen(p) + 1;
        memcpy(target, p, length);
        target += length;
    }
    FreeEnvironmentStringsA(source);
    target += sprintf(target, "%s=%s", PX_PLUGIN_TOKEN_ENV, token) + 1;
    *target = '\0';
    return block;
}

static int px_quote(char **cursor, const char *end, const char *value) {
    if (*cursor + 2 >= end) return 0;
    *(*cursor)++ = '"';
    for (const char *p = value; *p; p++) {
        if (*p == '"' || *p == '\\') {
            if (*cursor + 2 >= end) return 0;
            *(*cursor)++ = '\\';
        }
        if (*cursor + 1 >= end) return 0;
        *(*cursor)++ = *p;
    }
    if (*cursor + 2 >= end) return 0;
    *(*cursor)++ = '"';
    return 1;
}

static int px_read_line(PxPluginProcess *host, int timeout_ms,
    char *line, size_t capacity) {
    ULONGLONG deadline = GetTickCount64() + (ULONGLONG)timeout_ms;
    for (;;) {
        char *newline = host->buffer_length == 0 ? NULL
            : memchr(host->buffer, '\n', host->buffer_length);
        if (newline != NULL) {
            size_t length = (size_t)(newline - host->buffer);
            if (length >= capacity) length = capacity - 1;
            memcpy(line, host->buffer, length);
            line[length] = '\0';
            size_t consumed = (size_t)(newline - host->buffer) + 1;
            memmove(host->buffer, host->buffer + consumed,
                host->buffer_length - consumed);
            host->buffer_length -= consumed;
            return 1;
        }
        DWORD available = 0;
        if (!PeekNamedPipe(host->output, NULL, 0, NULL, &available, NULL))
            return 0;
        if (available > 0) {
            if (host->buffer_length >= PX_PLUGIN_FRAME_MAX - 1) return 0;
            DWORD read = 0;
            DWORD space = (DWORD)(PX_PLUGIN_FRAME_MAX - 1 - host->buffer_length);
            if (available > space) available = space;
            if (!ReadFile(host->output, host->buffer + host->buffer_length,
                    available, &read, NULL))
                return 0;
            host->buffer_length += read;
            continue;
        }
        if (GetTickCount64() >= deadline) return -1;
        Sleep(2);
    }
}

static void px_terminate(PxPluginProcess *host) {
    if (host == NULL) return;
    host->active = 0;
    if (host->process != NULL) {
        WaitForSingleObject(host->process, 1000);
        TerminateProcess(host->process, 1);
        WaitForSingleObject(host->process, 1000);
        CloseHandle(host->process);
        host->process = NULL;
    }
    if (host->input != NULL) {
        CloseHandle(host->input);
        host->input = NULL;
    }
    if (host->output != NULL) {
        CloseHandle(host->output);
        host->output = NULL;
    }
}

static int px_call(PxPluginProcess *host, const char *service,
    const char *method, const unsigned char *payload, size_t payload_length,
    unsigned char **response, size_t *response_length, const char **error,
    int timeout_ms) {
    *response = NULL;
    *response_length = 0;
    host->sequence++;
    char *encoded = px_b64_encode(payload, payload_length);
    if (encoded == NULL) {
        px_error(error, "INTERNAL");
        return 0;
    }
    char frame[PX_PLUGIN_FRAME_MAX];
    char *cursor = frame;
    char *end = frame + sizeof(frame) - 2;
    cursor += snprintf(cursor, (size_t)(end - cursor),
        "{\"id\":\"req-%llu\",\"version\":1,\"plugin_id\":\"", host->sequence);
    if (!px_escape(&cursor, end, host->plugin_id)) goto invalid;
    cursor += snprintf(cursor, (size_t)(end - cursor), "\",\"service\":\"");
    if (!px_escape(&cursor, end, service)) goto invalid;
    cursor += snprintf(cursor, (size_t)(end - cursor), "\",\"method\":\"");
    if (!px_escape(&cursor, end, method)) goto invalid;
    cursor += snprintf(cursor, (size_t)(end - cursor), "\",\"token\":\"");
    if (!px_escape(&cursor, end, host->token)) goto invalid;
    cursor += snprintf(cursor, (size_t)(end - cursor),
        "\",\"payload\":\"%s\"}\n", encoded);
    free(encoded);
    DWORD written = 0;
    if (!WriteFile(host->input, frame, (DWORD)strlen(frame), &written, NULL) ||
        written != (DWORD)strlen(frame)) {
        px_error(error, "INTERNAL");
        return 0;
    }
    char line[PX_PLUGIN_FRAME_MAX];
    int read = px_read_line(host, timeout_ms, line, sizeof(line));
    if (read == 0) {
        px_terminate(host);
        px_error(error, "INTERNAL");
        return 0;
    }
    if (read < 0) {
        px_terminate(host);
        px_error(error, "TIMEOUT");
        return 0;
    }
    PxArena arena;
    px_arena_init(&arena);
    PxValue *root = px_parse(&arena, line);
    int ok = 0;
    if (root != NULL && root->type == PX_OBJ) {
        PxValue *ok_value = px_obj_get(root, "ok");
        if (ok_value != NULL && ok_value->type == PX_BOOL &&
            ok_value->as.boolean) {
            const char *payload_text = px_get_str(root, "payload");
            if (payload_text != NULL) {
                *response = px_b64_decode(payload_text, response_length);
                if (*response != NULL) ok = 1;
            }
        } else {
            const char *code = px_get_str(root, "code");
            px_error(error, code == NULL ? "INTERNAL" : code);
        }
    }
    px_arena_free(&arena);
    if (!ok && *response == NULL && error != NULL && *error == NULL)
        px_error(error, "INTERNAL");
    return ok;
invalid:
    free(encoded);
    px_error(error, "INVALID_REQUEST");
    return 0;
}

PxPluginProcess *px_plugin_process_start(const PxPluginProcessConfig *config,
    const char **error) {
    px_error(error, NULL);
    if (config == NULL || config->plugin_id == NULL || config->path == NULL) {
        px_error(error, "INVALID_REQUEST");
        return NULL;
    }
    PxPluginProcess *host = calloc(1, sizeof(*host));
    if (host == NULL) {
        px_error(error, "INTERNAL");
        return NULL;
    }
#ifdef _WIN32
    host->process = NULL;
    host->input = NULL;
    host->output = NULL;
#else
    host->pid = 0;
    host->input = -1;
    host->output = -1;
#endif
    host->plugin_id = px_copy(config->plugin_id);
    host->buffer = calloc(1, PX_PLUGIN_FRAME_MAX);
    host->token = px_copy(config->token != NULL && config->token[0] != '\0'
        ? config->token : "0123456789abcdef0123456789abcdef");
    if (host->plugin_id == NULL || host->buffer == NULL || host->token == NULL)
        goto fail;
    char command[32768];
    char *cursor = command;
    char *end = command + sizeof(command);
    if (!px_quote(&cursor, end, config->path)) goto fail;
    for (int index = 0; index < config->arg_count; index++) {
        if (cursor + 1 >= end) goto fail;
        *cursor++ = ' ';
        if (!px_quote(&cursor, end, config->args[index])) goto fail;
    }
    *cursor = '\0';
    char *environment = px_environment(host->token);
    if (environment == NULL) goto fail;
    SECURITY_ATTRIBUTES attributes = { sizeof(attributes), NULL, TRUE };
    HANDLE stdin_read = NULL, stdin_write = NULL;
    HANDLE stdout_read = NULL, stdout_write = NULL;
    HANDLE stderr_write = CreateFileA("NUL", GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE, &attributes, OPEN_EXISTING, 0, 0);
    if (!CreatePipe(&stdin_read, &stdin_write, &attributes, 0) ||
        !CreatePipe(&stdout_read, &stdout_write, &attributes, 0) ||
        stderr_write == INVALID_HANDLE_VALUE) {
        free(environment);
        goto fail;
    }
    SetHandleInformation(stdin_write, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(stdout_read, HANDLE_FLAG_INHERIT, 0);
    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    memset(&startup, 0, sizeof(startup));
    memset(&process, 0, sizeof(process));
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = stdin_read;
    startup.hStdOutput = stdout_write;
    startup.hStdError = stderr_write;
    BOOL created = CreateProcessA(NULL, command, NULL, NULL, TRUE,
        CREATE_NO_WINDOW, environment, NULL, &startup, &process);
    free(environment);
    CloseHandle(stdin_read);
    CloseHandle(stdout_write);
    CloseHandle(stderr_write);
    if (!created) {
        CloseHandle(stdin_write);
        CloseHandle(stdout_read);
        goto fail;
    }
    CloseHandle(process.hThread);
    host->process = process.hProcess;
    host->input = stdin_write;
    host->output = stdout_read;
    int start_timeout = config->start_timeout_ms > 0
        ? config->start_timeout_ms : 10000;
    unsigned char *ignored = NULL;
    size_t ignored_length = 0;
    if (!px_call(host, "host.control", "health", NULL, 0, &ignored,
            &ignored_length, error, start_timeout)) {
        free(ignored);
        px_plugin_process_stop(host);
        return NULL;
    }
    free(ignored);
    host->invoke_timeout_ms = config->invoke_timeout_ms > 0
        ? config->invoke_timeout_ms : 30000;
    host->active = 1;
    return host;
fail:
    px_plugin_process_free(host);
    if (error != NULL && *error == NULL) px_error(error, "INTERNAL");
    return NULL;
}

int px_plugin_process_invoke(PxPluginProcess *host, const char *service,
    const char *method, const unsigned char *payload, size_t payload_length,
    unsigned char **response, size_t *response_length, const char **error) {
    if (host == NULL || !host->active) {
        px_error(error, "NOT_ACTIVE");
        return 0;
    }
    return px_call(host, service, method, payload, payload_length, response,
        response_length, error, host->invoke_timeout_ms);
}

void px_plugin_process_stop(PxPluginProcess *host) {
    if (host == NULL) return;
    if (host->active) {
        unsigned char *ignored = NULL;
        size_t ignored_length = 0;
        const char *error = NULL;
        px_call(host, "host.control", "shutdown", NULL, 0, &ignored,
            &ignored_length, &error, 5000);
        free(ignored);
    }
    px_terminate(host);
}

void px_plugin_process_free(PxPluginProcess *host) {
    if (host == NULL) return;
    px_terminate(host);
    free(host->plugin_id);
    free(host->token);
    free(host->buffer);
    free(host);
}

#else

PxPluginProcess *px_plugin_process_start(const PxPluginProcessConfig *config,
    const char **error) {
    (void)config;
    px_error(error, "PROVIDER_HTTP");
    return NULL;
}

int px_plugin_process_invoke(PxPluginProcess *host, const char *service,
    const char *method, const unsigned char *payload, size_t payload_length,
    unsigned char **response, size_t *response_length, const char **error) {
    (void)host; (void)service; (void)method; (void)payload;
    (void)payload_length; (void)response; (void)response_length;
    px_error(error, "NOT_ACTIVE");
    return 0;
}

void px_plugin_process_stop(PxPluginProcess *host) { (void)host; }
void px_plugin_process_free(PxPluginProcess *host) { (void)host; }

#endif
