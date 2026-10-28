# PRAXO-CORE Scala Sample

Scala consumes the Java Core; it is a sample, not a second contract
implementation. The sample runs on Scala 3 and the JVM.

## Build and run

```bash
# Compile the Java Core first.
find language/java/src/main/java -name '*.java' > java-sources.txt
javac -d language/java/build/classes @java-sources.txt

scala-cli run examples/scala/sample.scala --classpath language/java/build/classes --server=false
```

CI installs Scala CLI and runs the same sample.

## Usage

```scala
import io.axisvela.praxo.agent.{Agent, AgentOptions, Session}
import io.axisvela.praxo.model.{Message, Model, Request, Response}

val model = new Model:
  override def generate(request: Request): Response =
    Response.of(Message.of("assistant", "hello"))

val result = new Agent(new AgentOptions(model)).run(new Session("demo"), "hello")
println(result.output)
```

Tools, middleware, memory, checkpoints, policy, and streaming are the Java Core
APIs; do not create a separate Scala core.

## Release

No separate tag. Scala ships with the Java package `java/v0.2.1`.
