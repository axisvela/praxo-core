# PRAXO-CORE Kotlin Sample

Kotlin consumes the Java Core; it is a sample, not a second contract
implementation. The sample runs on the JVM.

## Build and run

```bash
# Compile the Java Core first.
find language/java/src/main/java -name '*.java' > java-sources.txt
javac -d language/java/build/classes @java-sources.txt

# Then compile and run the Kotlin sample.
kotlinc -cp language/java/build/classes -include-runtime -d examples/kotlin/sample.jar examples/kotlin/sample.kt
java -cp examples/kotlin/sample.jar:language/java/build/classes SampleKt
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

Tools, middleware, memory, checkpoints, policy, and streaming are the Java Core
APIs; do not create a separate Kotlin core.

## Release

No separate tag. Kotlin ships with the Java package `java/v0.2.1`.
