#include <fcntl.h>
#include <spawn.h>
#include <sys/socket.h>

extern char **environ;

static long long px_now_ms(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 0;
    return (long long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static int px_wait_fd(int fd, short events, long long deadline) {
    for (;;) {
        long long left = deadline - px_now_ms();
        if (left <= 0) return -1;
        struct pollfd item = {fd, events, 0};
        int result = poll(&item, 1, (int)left);
        if (result < 0 && errno == EINTR) continue;
        if (result == 0) return -1;
        if (result < 0 || !(item.revents & events)) return 0;
        return 1;
    }
}

static int px_read_line(PxPluginProcess *host, int timeout_ms,
    char *line, size_t capacity) {
    long long deadline = px_now_ms() + timeout_ms;
    for (;;) {
        char *newline = memchr(host->buffer, '\n', host->buffer_length);
        if (newline != NULL) {
            size_t length = (size_t)(newline - host->buffer);
            if (length >= capacity) return 0;
            memcpy(line, host->buffer, length);
            line[length] = '\0';
            size_t consumed = length + 1;
            host->buffer_length -= consumed;
            memmove(host->buffer, host->buffer + consumed, host->buffer_length);
            return 1;
        }
        if (host->buffer_length >= PX_PLUGIN_FRAME_MAX - 1) return 0;
        int ready = px_wait_fd(host->output, POLLIN, deadline);
        if (ready <= 0) return ready;
        ssize_t count = read(host->output, host->buffer + host->buffer_length,
            PX_PLUGIN_FRAME_MAX - 1 - host->buffer_length);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count <= 0) return 0;
        host->buffer_length += (size_t)count;
    }
}

static int px_write_frame(PxPluginProcess *host, const char *frame,
    size_t length, int timeout_ms) {
    long long deadline = px_now_ms() + timeout_ms;
    while (length > 0) {
        if (px_wait_fd(host->input, POLLOUT, deadline) <= 0) return 0;
        int flags = 0;
#ifdef MSG_NOSIGNAL
        flags = MSG_NOSIGNAL;
#endif
        ssize_t count = send(host->input, frame, length, flags);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count <= 0) return 0;
        frame += count;
        length -= (size_t)count;
    }
    return 1;
}

static void px_terminate(PxPluginProcess *host) {
    if (host == NULL) return;
    host->active = 0;
    if (host->input >= 0) close(host->input);
    if (host->output >= 0) close(host->output);
    host->input = host->output = -1;
    if (host->pid > 0) {
        int status;
        pid_t result;
        do {
            result = waitpid(host->pid, &status, WNOHANG);
        } while (result < 0 && errno == EINTR);
        if (result == 0) {
            kill(host->pid, SIGKILL);
            while (waitpid(host->pid, &status, 0) < 0 && errno == EINTR) {}
        }
        host->pid = 0;
    }
}

static int px_spawn(PxPluginProcess *host, const PxPluginProcessConfig *config) {
    int input[2] = {-1, -1}, output[2] = {-1, -1};
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, input) != 0) return 0;
    if (pipe(output) != 0) {
        close(input[0]); close(input[1]);
        return 0;
    }
    int fds[] = {input[0], input[1], output[0], output[1]};
    int ok = 0;
    for (size_t i = 0; i < 4; i++)
        if (fcntl(fds[i], F_SETFD, FD_CLOEXEC) < 0) goto done;
#ifdef SO_NOSIGPIPE
    int enabled = 1;
    if (setsockopt(input[0], SOL_SOCKET, SO_NOSIGPIPE,
            &enabled, sizeof(enabled)) != 0) goto done;
#endif
    size_t count = 0;
    while (environ[count] != NULL) count++;
    char **environment = calloc(count + 2, sizeof(char *));
    char **args = calloc((size_t)config->arg_count + 2, sizeof(char *));
    size_t token_size = strlen(PX_PLUGIN_TOKEN_ENV) + strlen(host->token) + 2;
    char *token = malloc(token_size);
    if (environment == NULL || args == NULL || token == NULL) {
        free(environment); free(args); free(token);
        goto done;
    }
    snprintf(token, token_size, "%s=%s", PX_PLUGIN_TOKEN_ENV, host->token);
    size_t target = 0;
    for (size_t i = 0; i < count; i++)
        if (strncmp(environ[i], PX_PLUGIN_TOKEN_ENV "=",
                strlen(PX_PLUGIN_TOKEN_ENV) + 1) != 0)
            environment[target++] = environ[i];
    environment[target] = token;
    args[0] = (char *)config->path;
    for (int i = 0; i < config->arg_count; i++) args[i + 1] = (char *)config->args[i];
    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions) == 0) {
        int result = posix_spawn_file_actions_adddup2(&actions, input[1], STDIN_FILENO);
        if (!result) result = posix_spawn_file_actions_adddup2(&actions, output[1], STDOUT_FILENO);
        if (!result) result = posix_spawn_file_actions_addopen(&actions, STDERR_FILENO,
            "/dev/null", O_WRONLY, 0);
        pid_t pid;
        if (!result) result = posix_spawnp(&pid, config->path, &actions,
            NULL, args, environment);
        posix_spawn_file_actions_destroy(&actions);
        if (!result) {
            host->pid = pid;
            host->input = input[0];
            host->output = output[0];
            input[0] = output[0] = -1;
            ok = 1;
            if (fcntl(host->input, F_SETFL, O_NONBLOCK) < 0) {
                px_terminate(host);
                ok = 0;
            }
        }
    }
    free(environment); free(args); free(token);
done:
    if (input[0] >= 0) close(input[0]);
    if (input[1] >= 0) close(input[1]);
    if (output[0] >= 0) close(output[0]);
    if (output[1] >= 0) close(output[1]);
    return ok;
}
