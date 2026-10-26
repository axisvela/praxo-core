# PRAXO-CORE Kotlin Sample

Kotlin consumes the Java SDK; it is a sample, not a second contract
implementation. The sample runs on the JVM.

## Build and run

```bash
# Compile the Java SDK first.
find sdk/java/src/main/java -name '*.java' > java-sources.txt
javac -d sdk/java/build/classes @java-sources.txt

# Then compile and run the Kotlin sample.
kotlinc -cp sdk/java/build/classes -include-runtime -d examples/kotlin/sample.jar examples/kotlin/sample.kt
java -cp examples/kotlin/sample.jar:sdk/java/build/classes SampleKt
```

CI installs Kotlin and runs the same sample.

## Usage

```kotlin
val model = object : Model {
    override fun generate(request: Request): Response =
        Response.of(Message.of("assistant", "hello"))
}

val result = Agent(AgentOptions(model)).run(Session("demo"), "hello")
println(result.output)
```

Tools, middleware, memory, checkpoints, policy, and streaming are the Java SDK
APIs; do not create a separate Kotlin core.

## Release

No separate tag. Kotlin ships with the Java package `java/v0.2.1`.
