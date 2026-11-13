# Independent Elixir Consumer

Use published Hex `praxo_core` `0.8.0` in your own application with Elixir 1.14
or newer. No PRAXO-CORE source checkout, API key, model service, or AxisVela
product is required. Installation needs Hex access or a cached package.

This is an extended-language starter. It demonstrates the allow/deny path but is
not one of the four pilot languages that carry the governed negative matrix.

## Choose the Boundary

This is a fit for an embedded model/tool loop with explicit tool scope and
policy. Your application still owns model access, authentic identity, persistent
approvals, external effects, and isolation. It is not a hosted agent platform,
durable graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Create the Application

Declare the exact dependency in `mix.exs`:

```elixir
defp deps do
  [
    {:praxo_core, "~> 0.8.0"}
  ]
end
```

Then run `mix deps.get`. Do not use a `path:` dependency or a checkout of the
language source directory for acceptance.

## Application Source

Use the following as `starter.exs`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-elixir/starter.exs).

<!-- elixir-consumer-source: starter.exs -->

## Acceptance Tests

Use the following as `test_starter.exs`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-elixir/test_starter.exs).

<!-- elixir-consumer-source: test_starter.exs -->

## Verify

```sh
mix deps.get
mix run test_starter.exs
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowed_tools` limits the tool
name; Policy also checks the target argument. A denied private target returns
`AGENT_POLICY_DENIED` and must not increment the in-memory counter. Keep these
tests when replacing the fixture with a real adapter.

For a source checkout without Hex, compile the beams and run with
`elixir -pa language/elixir/build/ebin test_starter.exs`; that path is not
independent consumer evidence.

## Scope

This starter establishes only the stated Hex package and fixture behavior. It
does not add the governed negative matrix, prove authentic identity, provide
durable approvals, reconcile effects, or establish isolation. Continue with the
[Elixir implementation guide](../languages/elixir/index.md) and the
[security model](../security/index.md).
