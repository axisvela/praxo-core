# Checkpoint Allowlist

This example uses the Fortran Core checkpoint allowlist to encode and decode
only registered payload types. Build after `python language/fortran/run-tests.py`
has populated `language/fortran/build`:

```bash
mkdir -p build/fortran-example
gfortran -I language/fortran/build -J build/fortran-example \
  -c language/fortran/src/praxo_checkpoint.f90 \
  -o build/fortran-example/praxo_checkpoint.o
gfortran -I language/fortran/build -I build/fortran-example \
  language/fortran/examples/checkpoint/checkpoint_example.f90 \
  build/fortran-example/praxo_checkpoint.o \
  language/fortran/build/praxo_types.o \
  language/fortran/build/praxo_json.o \
  language/fortran/build/praxo_unicode.o \
  -o build/fortran-example/checkpoint_example
./build/fortran-example/checkpoint_example
```

Expected output:

```text
Fortran checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
