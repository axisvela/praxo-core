#include <stdio.h>
#include <string.h>

typedef int (*Call)(void *context, const char **error);

static int with_fallback(Call primary, void *primary_context,
        Call fallback, void *fallback_context, const char **error) {
    *error = NULL;
    if (primary(primary_context, error) == 0) {
        return 0;
    }
    if (fallback(fallback_context, error) == 0) {
        return 0;
    }
    *error = "MODEL_UNAVAILABLE";
    return -1;
}

typedef struct {
    int calls;
    int failures;
} Model;

static int model_call(void *context, const char **error) {
    Model *model = context;
    model->calls++;
    if (model->calls <= model->failures) {
        *error = "MODEL_UNAVAILABLE";
        return -1;
    }
    return 0;
}

int main(void) {
    const char *error = NULL;
    Model primary = {0, 0};
    Model fallback = {0, 0};
    if (with_fallback(model_call, &primary, model_call, &fallback, &error) != 0
            || fallback.calls != 0) {
        return 1;
    }

    primary = (Model){0, 1};
    fallback = (Model){0, 0};
    if (with_fallback(model_call, &primary, model_call, &fallback, &error) != 0
            || primary.calls != 1 || fallback.calls != 1) {
        return 1;
    }

    primary = (Model){0, 1};
    fallback = (Model){0, 1};
    if (with_fallback(model_call, &primary, model_call, &fallback, &error) != -1
            || strcmp(error, "MODEL_UNAVAILABLE") != 0) {
        return 1;
    }

    printf("C provider fallback example passed\n");
    return 0;
}
