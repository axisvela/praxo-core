# C# test generation (SE-04)

A bounded first slice of [SE-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a test-execution or load-testing service. It generates three bounded tests for
a fixed local fixture and records zero executions. No load target, network traffic
or runtime verification.

## Why this language and runtime?

- **Selection basis:** A .NET engineering team can keep a test-drafting step in the
  same toolchain and CI conventions.
- **Demonstrated fit:** Fixed fixture metadata produces three review-only tests; no
  test runner, coverage tool or load target is executed.
- **Choose when:** Learning the Core seam around existing .NET test tooling.
- **Do not choose when:** Seeking actual test generation or execution. Compare the
  existing test framework, analyzers and coverage pipeline first.
- **Evidence limit:** Core integration fixture only; no compiled tests, execution,
  coverage measurement, network load or verified result.

Build and run from the repository root:

```bash
dotnet build language/csharp/Tutorial/test-generation/TestGeneration.csproj --nologo
dotnet language/csharp/Tutorial/test-generation/bin/Debug/net8.0/Praxo.TestGeneration.dll --test
dotnet language/csharp/Tutorial/test-generation/bin/Debug/net8.0/Praxo.TestGeneration.dll
dotnet language/csharp/Tutorial/test-generation/bin/Debug/net8.0/Praxo.TestGeneration.dll --fixture fixture-200
dotnet language/csharp/Tutorial/test-generation/bin/Debug/net8.0/Praxo.TestGeneration.dll --simulate-failure
```

Expected test output:

```text
success: fixture-100 functions=2 tests=3 status=draft_only executions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: FIXTURE_INDEX_UNAVAILABLE reads=1
```

`fixture-200` is denied by policy before the tool runs. `--simulate-failure` reads
once, reports `FIXTURE_INDEX_UNAVAILABLE`, and exits nonzero.

`read_fixture` returns 2 functions with last failure `parse` in C# for
`fixture-100`; `draft_tests` returns 3 generated tests covering `parse`/`format`
with `status=draft_only`, `review_required=true`, `executions=0` and
`load_targets=0`. Policy limits the fixture and final `generate_tests` action.

Real execution, coverage measurement and loopback load testing belong to the
consumer.
