# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary failure when both fail.

```bash
gfortran language/fortran/examples/provider-fallback/fallback_example.f90 \
  -o build/fortran-fallback
./build/fortran-fallback
```

Expected output:

```text
Fortran provider fallback example passed
```
