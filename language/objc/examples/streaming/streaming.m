#import <stdio.h>
#import <string.h>

int main(void) {
    const char *chunks[] = {"status: ", "green"};
    char output[32] = {0};
    char received[32] = {0};
    for (int i = 0; i < 2; i++) {
        strcat(output, chunks[i]);
        strcat(received, chunks[i]);
    }
    if (strcmp(output, "status: green") != 0 || strcmp(received, output) != 0) return 1;
    printf("Objective-C streaming example passed\n");
    return 0;
}
