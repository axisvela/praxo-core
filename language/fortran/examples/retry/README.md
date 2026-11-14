# Retry

This example retries a transient failure with a bounded attempt count and keeps
the exhausted failure state.

```bash
gfortran language/fortran/examples/retry/retry_example.f90 \
  -o build/fortran-retry
./build/fortran-retry
```

Expected output:

```text
Fortran retry example passed
```
