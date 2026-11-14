#include <stdio.h>
#include <string.h>

typedef struct {
    int status;
    const char *body;
} Response;

static Response handle(const char *method, const char *path,
        const char *principal, const char *body) {
    if (strcmp(method, "GET") == 0 && strcmp(path, "/healthz") == 0) {
        return (Response){200, "{\"status\":\"ok\"}"};
    }
    if (strcmp(method, "POST") != 0 || strcmp(path, "/run") != 0) {
        return (Response){404, "{\"error\":\"not found\"}"};
    }
    if (principal == NULL || principal[0] == '\0') {
        return (Response){401, "{\"error\":\"missing X-Praxo-Principal\"}"};
    }
    if (body == NULL || strstr(body, "\"prompt\"") == NULL) {
        return (Response){400, "{\"error\":\"prompt is required\"}"};
    }
    return (Response){200, "{\"output\":\"hello from the service\"}"};
}

int main(void) {
    Response response = handle("GET", "/healthz", NULL, "");
    if (response.status != 200) return 1;
    response = handle("POST", "/run", NULL, "{\"prompt\":\"hi\"}");
    if (response.status != 401) return 1;
    response = handle("POST", "/run", "user-1", "{\"prompt\":\"hi\"}");
    if (response.status != 200 ||
            strstr(response.body, "hello from the service") == NULL) return 1;
    printf("C service example passed\n");
    return 0;
}
