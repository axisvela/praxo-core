# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary error when both fail.

```bash
gcc -std=c11 language/c/examples/provider-fallback/main.c -o build/c-fallback
./build/c-fallback
```

Expected output:

```text
C provider fallback example passed
```
