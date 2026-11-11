# Independent Java Consumer

This starter installs the published `com.axisvela:praxo-core:0.5.0` artifact from
Maven Central in a separate application. It does not compile or import the
repository's Java source. Java 21 or newer and Maven 3.9 or newer are required.
PRAXO-CORE has no runtime dependencies.

From this directory:

```sh
mvn -B test
mvn -q -B exec:java
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests a tool. `allowedTools` scope and Policy restrict
the target. A denied call raises `PraxoException` with code
`AGENT_POLICY_DENIED` and must not increment the in-memory counter. Tests also
verify the SDK version and that `Version` was loaded from the published
`praxo-core-0.5.0.jar` in the local Maven repository.

`GovernedAcceptanceTest` adds five negative checks: missing mandatory policy,
empty tool scope, middleware final-argument change, approval-edit
reauthorization, and policy-service failure. Every rejected path must leave the
counter at zero. The guard is application-level; Core keeps its ordinary
nil-policy behavior and this is not a general security profile.

Installation needs Maven Central access or a populated local repository.
Execution needs no API key, model service, or AxisVela product. This does not
prove live-model quality, authentic identity, isolation, or durable effects.

For a new application outside this repository, follow the
[consumer guide](../../docs/getting-started/consumer-java.md). From the repository
root, `python scripts/test_java_consumer.py -v` repeats the flow in a fresh
temporary project.
