# Independent Java Consumer

Use the published `com.axisvela:praxo-core:0.4.0` artifact from Maven Central in
your own application. Java 21 or newer and Maven 3.9 or newer are required. No
PRAXO-CORE source checkout, API key, model service, or AxisVela product is
needed. Installation needs Maven Central access or a populated local repository.

## Choose the Boundary

This fits an embedded model/tool loop with explicit tool scope and policy. Your
application still owns model access, authentic identity, persistent approvals,
external effects, and isolation. It is not a hosted agent platform, durable
graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Create the Application

Declare the exact dependency in `pom.xml`:

```xml
<dependency>
  <groupId>com.axisvela</groupId>
  <artifactId>praxo-core</artifactId>
  <version>0.4.0</version>
</dependency>
```

Do not use a `system` scope, a local JAR path, or a substitute build of the
repository source. The tests verify the SDK version and that `Version` loaded
from the published `praxo-core-0.4.0.jar`.

## Application Source

Use the following as `src/main/java/starter/App.java`, rendered directly from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-java/src/main/java/starter/App.java).

<!-- java-consumer-source: App.java -->

## Acceptance Tests

Use the following as `src/test/java/starter/AppTest.java`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-java/src/test/java/starter/AppTest.java).

<!-- java-consumer-source: AppTest.java -->

## Verify

```sh
mvn -B test
mvn -q -B exec:java
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowedTools` limits the tool
name; Policy also checks the target argument. A denied call raises
`PraxoException` with code `AGENT_POLICY_DENIED` and must not increment the
in-memory counter. An empty allowlist is not deny-all in the current API. Keep
these tests when replacing the fixture with a real model adapter.

These checks establish only the stated artifact and fixture behavior, not live
model quality, authentic identity, isolation, durable effects, or production
safety. Continue with the [Java implementation guide](../languages/java/index.md)
and the [security model](../security/index.md).
