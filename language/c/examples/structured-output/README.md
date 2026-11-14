# Structured Output

This example validates a final JSON answer against a schema and rejects invalid
output.

```bash
gcc -std=c11 -I language/c/include language/c/examples/structured-output/main.c \
  language/c/build/libpraxo_core.a -o build/c-structured-output
./build/c-structured-output
```

Expected output:

```text
C structured output example passed
```
