# Independent TypeScript Consumer

This starter installs the published `@axisvela/praxo-core@0.2.0` package from
npm in a separate application. It does not import the repository's TypeScript
source. Node.js 20 or newer is required; the framework has no runtime
dependencies.

From this directory:

```sh
npm ci --no-audit --no-fund
npm test
node starter.js
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests a tool. Explicit `allowedTools` scope and
Policy restrict the target. A rejected call throws `PolicyDeniedError` and must
not increment the in-memory counter. Tests also verify that the package resolves
inside the application and that the dependency is the pinned registry version.

`governed.test.js` adds five negative checks: missing mandatory policy, empty
tool scope, middleware final-argument change, approval-edit reauthorization, and
policy-service failure. Every rejected path must leave the counter at zero. The
guard is application-level; Core keeps its ordinary nil-policy behavior and this
is not a general security profile.

Installation needs npm registry access or a populated cache. Execution needs no
API key, model service, or AxisVela product. This does not prove live-model
quality, authentic identity, isolation, or durable effects.

For a new application outside this repository, follow the
[consumer guide](../../docs/getting-started/consumer-typescript.md). From the
repository root, `python scripts/test_typescript_consumer.py -v` repeats the
flow in a fresh temporary project.
