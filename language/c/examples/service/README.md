# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any C HTTP server.

```bash
gcc -std=c11 language/c/examples/service/main.c -o build/c-service
./build/c-service
```

Expected output:

```text
C service example passed
```
