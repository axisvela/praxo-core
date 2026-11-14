# Checkpoint Allowlist

This example uses the Objective-C Core checkpoint allowlist for a registered
payload round trip.

```bash
clang -fobjc-arc -Ilanguage/objc \
  language/objc/examples/checkpoint/checkpoint.m language/objc/PraxoCore.m \
  language/objc/PraxoJSON.m -framework Foundation -o build/objc-checkpoint
./build/objc-checkpoint
```

Expected output:

```text
Objective-C checkpoint example passed
```
