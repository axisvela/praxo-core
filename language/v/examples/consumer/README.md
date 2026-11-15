# Independent V Consumer

This starter uses the V Core with a deterministic model. It does not require a
network connection, credentials, or a model service.

From the repository root:

```bash
v -path "language/v|@vlib|@vmodules" language/v/examples/consumer/consumer.v
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests one `record` tool call. An explicit tool scope
limits calls to `record`, and the policy denies the target `private`. A rejected
call must leave the tool call counter at zero.

The V policy hook receives only the action kind, so the example binds the
requested target when it builds the run and relies on `agent_allowed_tools` for
the tool-name check. This is an application-level guard, not a production
security profile.
