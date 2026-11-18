# PRAXO-CORE Clojure Sample

Clojure consumes the Java Core; it is a sample, not a second contract
implementation. The sample runs on the JVM.

## Build and run

```bash
# Compile the Java Core first.
find language/java/src/main/java -name '*.java' > java-sources.txt
javac -d language/java/build/classes @java-sources.txt

# Then run the Clojure sample.
CLASSPATH=language/java/build/classes clojure language/clojure/examples/sample.clj
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

Tools, middleware, memory, checkpoints, policy, and streaming are the Java Core
APIs; do not create a separate Clojure core.

## Representative Chain and Governance

Clojure uses the Java Core directly. Run the host language examples instead of
creating a separate Clojure chain:

- [Java representative chain](../../java/examples/representative-chain/)
- [Java advanced delegation](../../java/examples/advanced-delegation/README.md)

## Release

No separate tag. Clojure ships with the Java package `java/v0.2.1`.
