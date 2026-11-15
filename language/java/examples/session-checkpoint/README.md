# Java Session Checkpoint

This example uses published Maven Central `com.axisvela:praxo-core:0.9.0` and
the checkpoint allowlist to save, restore, and continue a multi-turn session.

## Run

```bash
cd language/java/examples/session-checkpoint
mvn -q compile exec:java
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once
guarantee. The embedding application owns durable storage, identity, and
concurrent-writer coordination.
