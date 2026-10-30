# Native Regex Dependencies

The agent loop remains native Fortran. Pattern matching now links an original
C ABI adapter to upstream RE2, rather than reimplementing a regex subset.

| Dependency | Revision | License |
| --- | --- | --- |
| RE2 2025-11-05 | `927f5d53caf8111721e734cf24724686bb745f55` | BSD-3-Clause |
| Abseil 20250512.1 | `76bb24329e8bf5f39704eb10d21b9a80befa7c81` | Apache-2.0 |

Sources are fetched from the official Google/Abseil repositories at immutable
revisions. No upstream source is copied into this repository. Their licenses
are compatible with this MIT framework; their original terms still apply.
`cmake --install` installs both upstream license files alongside the bridge.
Redistributors must retain those files and any additional required notices,
including notices required for a C++ runtime they distribute.

The bridge uses RE2's default syntax and UTF-8 encoding, builtin Unicode tables,
partial/search matching, and an 8 MiB regex memory budget. ICU is not used.
The budget is RE2's `Options::max_mem`, not an OS-enforced process memory cap.
It does not implement PCRE lookaround or backreferences, Unicode normalization,
locale-sensitive matching, or a claim of identical behavior to every Go regexp
version. Go and RE2 syntax and Unicode tables may differ; test consumer patterns.

Limits remain 4096 pattern bytes and 262144 subject bytes. Inputs cross the ABI
with explicit byte lengths, preserving embedded NUL and trailing spaces.
The bridge status values are 0 (non-match), 1 (match), 2 (regex syntax),
3 (resource/input-size limit), and 4 (unexpected ABI/runtime failure); the
Fortran entry point maps them to existing local error statuses. The C ABI is
an implementation detail, not a new shared wire contract or stable public SDK.
Invalid UTF-8 is rejected by the Fortran entry point. Invalid regex syntax is
an error, not a successful non-match. Resource exhaustion is an error, not a pass.

The new compiler, native library, and C++ runtime requirements are a pre-1.0
deployment change, so the source/API baseline advances to `0.3.0`. The historical
`fortran/v0.2.2` source tag retains the dependency-free bounded ASCII matcher.
