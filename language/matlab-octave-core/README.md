# PRAXO-CORE MATLAB/Octave shared core

Shared implementation used by the MATLAB and Octave packages. It is not a
standalone package; use the MATLAB or Octave registry entry.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: shared source
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Service authentication

The shared service authentication sample provides a principal struct, an
injectable introspection authenticator, and a revocation client for RFC 7662
and RFC 7009.

- Module path: `language/matlab-octave-core/+praxo_service/`
- Tests: `language/matlab-octave-core/tests/test_service_auth.m`
- Transport seam: function handle `(url, form, authorization)` returning
  `struct('status', ..., 'body', ...)`; pass `''` for no authorization header.

Run from the repository root:

```bash
octave-cli --eval "addpath('language/matlab-octave-core'); addpath('language/matlab-octave-core/tests'); test_service_auth"
```

unverified: toolchain absent (MATLAB and Octave are not installed).
