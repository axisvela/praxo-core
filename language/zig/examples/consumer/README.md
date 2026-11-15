# Independent Zig Consumer

This starter uses the Zig Core agent loop with a deterministic model. It does
not require a network connection, credentials, or a model service.

From the repository root:

```bash
mkdir -p build
zig build-exe language/zig/examples/consumer/consumer.zig \
  --dep agent --dep json --dep models \
  -Mroot=language/zig/examples/consumer/consumer.zig \
  -Magent=language/zig/src/agent.zig \
  -Mjson=language/zig/src/json.zig \
  -Mmodels=language/zig/src/models.zig \
  -femit-bin=build/zig-consumer
./build/zig-consumer
```

On Windows use `build\zig-consumer.exe`.

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests one `record` tool call. An explicit tool scope
limits calls to `record`, and the policy inspects the tool arguments and denies
the target `private`. A rejected call must leave the in-memory counter at zero.
