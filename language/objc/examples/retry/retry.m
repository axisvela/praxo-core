#import <stdio.h>

typedef struct {
    const char *output;
    const char *code;
    int calls;
} Outcome;

static Outcome run_retry(int failures, int max_attempts) {
    for (int attempt = 1; attempt <= max_attempts; attempt++) {
        if (attempt > failures) {
            return (Outcome){"status: green", NULL, attempt};
        }
    }
    return (Outcome){NULL, "MODEL_UNAVAILABLE", max_attempts};
}

int main(void) {
    Outcome recovered = run_retry(2, 3);
    if (recovered.output == NULL || recovered.calls != 3) return 1;
    Outcome exhausted = run_retry(3, 3);
    if (exhausted.code == NULL || exhausted.calls != 3) return 1;
    printf("Objective-C retry example passed\n");
    return 0;
}
