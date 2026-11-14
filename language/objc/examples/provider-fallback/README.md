# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary failure when both fail.

```bash
clang -x objective-c language/objc/examples/provider-fallback/fallback.m \
  -o build/objc-fallback
./build/objc-fallback
```

Expected output:

```text
Objective-C provider fallback example passed
```
