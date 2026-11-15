# Structured Output

This example validates a final JSON answer against a schema and rejects invalid
output.

```bash
clang -fobjc-arc -Ilanguage/objc/src \
  language/objc/examples/structured-output/structured_output.m \
  language/objc/src/PraxoJsonSchema.m language/objc/src/PraxoJSON.m \
  -framework Foundation -o build/objc-structured-output
./build/objc-structured-output
```

Expected output:

```text
Objective-C structured output example passed
```
