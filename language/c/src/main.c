#include "praxo.h"

#include <stdio.h>
#include <stdlib.h>

int px_run_conformance(const char *root);

int main(void) {
    char *root = px_repo_root();
    if (root == NULL) {
        fprintf(stderr, "repository root not found\n");
        return 1;
    }
    int result = px_run_conformance(root);
    free(root);
    return result;
}
