# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
clang -fobjc-arc language/objc/examples/service/service.m \
  -framework Foundation -o build/objc-service
./build/objc-service
```

Expected output:

```text
Objective-C service example passed
```
