# Checkpoint Allowlist

This example uses the Objective-C Core checkpoint allowlist for a registered
payload round trip.

```bash
clang -fobjc-arc -Ilanguage/objc/src \
  language/objc/examples/checkpoint/checkpoint.m language/objc/src/PraxoCore.m \
  language/objc/src/PraxoJSON.m -framework Foundation -o build/objc-checkpoint
./build/objc-checkpoint
```

Expected output:

```text
Objective-C checkpoint example passed
```
