# PRAXO-CORE Groovy Sample

Groovy consumes the Java SDK; it is a sample, not a second contract
implementation. The sample runs on the JVM.

## Build and run

```bash
# Compile the Java SDK first.
find language/java/src/main/java -name '*.java' > java-sources.txt
javac -d language/java/build/classes @java-sources.txt

# Then run the Groovy sample.
groovy -cp language/java/build/classes examples/groovy/sample.groovy
```

CI installs Groovy and runs the same sample.

## Usage

```groovy
def model = new Model() {
    Response generate(Request request) {
        return Response.of(Message.of("assistant", "hello"))
    }
}

def result = new Agent(new AgentOptions(model)).run(new Session("demo"), "hello")
println result.output
```

Tools, middleware, memory, checkpoints, policy, and streaming are the Java SDK
APIs; do not create a separate Groovy core.

## Release

No separate tag. Groovy ships with the Java package `java/v0.2.1`.
