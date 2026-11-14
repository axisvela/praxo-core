#include <stdio.h>
#include <string.h>

typedef int (*Attempt)(void *context, const char **error);

typedef struct {
    int calls;
    int failures;
} Flaky;

static int flaky(void *context, const char **error) {
    Flaky *state = context;
    state->calls++;
    if (state->calls <= state->failures) {
        *error = "MODEL_UNAVAILABLE";
        return -1;
    }
    return 0;
}

static int retry(Attempt attempt, void *context, int max_attempts,
        const char **error) {
    for (int index = 1; index <= max_attempts; index++) {
        if (attempt(context, error) == 0) {
            return 0;
        }
        if (strcmp(*error, "MODEL_UNAVAILABLE") != 0 || index == max_attempts) {
            return -1;
        }
    }
    return -1;
}

int main(void) {
    const char *error = NULL;
    Flaky recovered = {0, 2};
    if (retry(flaky, &recovered, 3, &error) != 0 || recovered.calls != 3) {
        return 1;
    }

    Flaky exhausted = {0, 3};
    if (retry(flaky, &exhausted, 3, &error) != -1
            || strcmp(error, "MODEL_UNAVAILABLE") != 0
            || exhausted.calls != 3) {
        return 1;
    }

    printf("C retry example passed\n");
    return 0;
}
