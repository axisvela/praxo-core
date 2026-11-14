# Structured Output

This example uses published crates.io `praxo-core@0.8.0` to validate the final
answer against a JSON Schema.

`AgentOptions.structured_output` installs middleware that requests the schema
from the provider and validates the final output. Invalid output is rejected
with `AGENT_STRUCTURED_OUTPUT`.

## Run the deterministic test

No endpoint is required:

```bash
cargo run
```

Expected output:

```text
structured output test: ok
```

The run checks a valid summary and an invalid summary that omits required
fields.

## Wiring a real adapter

Replace the fake model with a published provider adapter. Keep the schema at the
application boundary and treat validation failure as a typed error rather than
parsing unvalidated text.
