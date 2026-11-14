# Structured Output

This example validates a final JSON answer against a schema and rejects invalid
output.

```bash
zig build-exe language/zig/examples/structured-output/structured_output.zig \
  --dep json --dep jsonschema \
  -Mroot=language/zig/examples/structured-output/structured_output.zig \
  -Mjson=language/zig/src/json.zig -Mjsonschema=language/zig/src/jsonschema.zig \
  -femit-bin=build/zig-structured-output
./build/zig-structured-output
```

Expected output:

```text
Zig structured output example passed
```
