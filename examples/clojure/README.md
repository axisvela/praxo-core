# PRAXO-CORE Clojure Sample

Clojure consumes the Java SDK; it is a sample, not a second contract
implementation. The sample runs on the JVM.

## Build and run

```bash
# Compile the Java SDK first.
find language/java/src/main/java -name '*.java' > java-sources.txt
javac -d language/java/build/classes @java-sources.txt

# Then run the Clojure sample.
CLASSPATH=language/java/build/classes clojure examples/clojure/sample.clj
```

CI installs Clojure and runs the same sample.

## Usage

```clojure
(def model
  (reify Model
    (generate [_ request]
      (Response/of (Message/of "assistant" "hello")))))

(def result (.run (Agent. (AgentOptions. model)) (Session. "demo") "hello"))
(println (.output result))
```

Tools, middleware, memory, checkpoints, policy, and streaming are the Java SDK
APIs; do not create a separate Clojure core.

## Release

No separate tag. Clojure ships with the Java package `java/v0.2.1`.
