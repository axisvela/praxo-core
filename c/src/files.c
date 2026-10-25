#include "praxo.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#define GETCWD _getcwd
#define PATH_SEP '\\'
#else
#include <unistd.h>
#define GETCWD getcwd
#define PATH_SEP '/'
#endif

char *px_read_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long size = ftell(file);
    if (size < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    char *data = calloc(1, (size_t)size + 1);
    if (data == NULL) {
        fclose(file);
        return NULL;
    }
    if (fread(data, 1, (size_t)size, file) != (size_t)size) {
        free(data);
        fclose(file);
        return NULL;
    }
    fclose(file);
    return data;
}

char *px_repo_root(void) {
    char path[2048];
    if (GETCWD(path, sizeof(path)) == NULL) {
        return NULL;
    }
    while (true) {
        char probe[2300];
        snprintf(probe, sizeof(probe), "%s%cspec%cSPEC_VERSION",
                 path, PATH_SEP, PATH_SEP);
        FILE *file = fopen(probe, "rb");
        if (file != NULL) {
            fclose(file);
            size_t size = strlen(path);
            char *out = malloc(size + 1);
            if (out != NULL) {
                memcpy(out, path, size + 1);
            }
            return out;
        }
        char *slash = strrchr(path, PATH_SEP);
        if (slash == NULL || slash == path) {
            return NULL;
        }
        *slash = '\0';
    }
}
