#ifndef PRAXO_FORTRAN_RE2_BRIDGE_H
#define PRAXO_FORTRAN_RE2_BRIDGE_H

#include <stddef.h>

#if defined(_WIN32) && defined(praxo_re2_EXPORTS)
#define PRAXO_RE2_API __declspec(dllexport)
#elif defined(_WIN32)
#define PRAXO_RE2_API __declspec(dllimport)
#else
#define PRAXO_RE2_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

PRAXO_RE2_API int praxo_re2_match(const char *pattern, size_t pattern_size,
                                const char *text, size_t text_size);

#ifdef __cplusplus
}
#endif
#endif
