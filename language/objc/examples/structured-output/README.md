# Structured Output

This example validates a final JSON answer against a schema and rejects invalid
output.

```bash
clang -fobjc-arc -Ilanguage/objc \
  language/objc/examples/structured-output/structured_output.m \
  language/objc/PraxoJsonSchema.m language/objc/PraxoJSON.m \
  -framework Foundation -o build/objc-structured-output
./build/objc-structured-output
```

Expected output:

```text
Objective-C structured output example passed
```
