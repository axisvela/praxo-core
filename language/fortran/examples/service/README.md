# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Fortran HTTP server.

```bash
gfortran language/fortran/examples/service/service_example.f90 \
  -o build/fortran-service
./build/fortran-service
```

Expected output:

```text
Fortran service example passed
```
