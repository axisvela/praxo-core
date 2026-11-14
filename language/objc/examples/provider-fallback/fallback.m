#import <stdio.h>
#import <string.h>

static const char *run_fallback(int primary_fails, int fallback_fails) {
    if (!primary_fails) return "primary";
    if (!fallback_fails) return "fallback";
    return "MODEL_UNAVAILABLE";
}

int main(void) {
    if (strcmp(run_fallback(0, 0), "primary") != 0) return 1;
    if (strcmp(run_fallback(1, 0), "fallback") != 0) return 1;
    if (strcmp(run_fallback(1, 1), "MODEL_UNAVAILABLE") != 0) return 1;
    printf("Objective-C provider fallback example passed\n");
    return 0;
}
