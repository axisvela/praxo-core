# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
octave-cli --path language/matlab/examples/service --eval service_example
```

Expected output:

```text
MATLAB service example passed
```

## Service authentication

RFC 7662 introspection and RFC 7009 revocation are implemented in the shared
MATLAB/Octave service package:

- Module path: `language/matlab-octave-core/+praxo_service/`
- Test path: `language/matlab-octave-core/tests/test_service_auth.m`
- Transport seam: function handle `(url, form, authorization)` returning
  `struct('status', ..., 'body', ...)`; pass `''` for no authorization header.

```bash
octave-cli --eval "addpath('language/matlab-octave-core'); addpath('language/matlab-octave-core/tests'); test_service_auth"
```

unverified: toolchain absent (MATLAB and Octave are not installed).
