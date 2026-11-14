# Streaming

This example collects agent stream parts from the Fortran Core and checks the
`values` and `messages` lifecycle.

Build against the modules produced by `python language/fortran/run-tests.py`:

```bash
gfortran -I language/fortran/build \
  language/fortran/examples/streaming/streaming_example.f90 \
  language/fortran/build/praxo_types.o language/fortran/build/praxo_interfaces.o \
  -o build/fortran-streaming
```

Expected output:

```text
Fortran streaming example passed
```
