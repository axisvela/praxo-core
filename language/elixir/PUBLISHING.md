# Publishing the Elixir Core

## Status

The Hex package `praxo_core` `0.3.0` has been built from source tag
`elixir/v0.3.0`, but it has **not** been uploaded because no Hex API key is
configured in this environment. The built artifact is
`language/elixir/praxo_core-0.3.0.tar` (local, not committed).

## Build

```bash
cd language/elixir
mix hex.build
```

Local gates:

```bash
elixirc -o build/ebin lib/praxo/*.ex
elixir -pa build/ebin tests/run_tests.exs
elixir -pa build/ebin conformance/run.exs
python language/elixir/api-snapshot.py --check
```

## Publish

Authenticate once, then publish:

```bash
cd language/elixir
mix hex.user auth
mix hex.publish
```

Or set `HEX_API_KEY` for the command environment. Do not put the key in the
repository.

## Credentials and configuration

- Hex config: `C:\Users\hanhw1\.hex\hex.config`.
- `mix hex.config` currently reports `api_key: nil`. Configure it with
  `mix hex.user auth` or set `HEX_API_KEY`.
- HexDocs are published by `mix hex.publish` when `docs` is enabled.
- Network: the environment uses an HTTPS proxy with TLS interception. If Hex
  reports a certificate error, export the trusted `mitmproxy` root from the
  Windows certificate store and point the tool at it; do not disable TLS
  verification.

## Verify

```bash
mix hex.info praxo_core
```

Registry: <https://hex.pm/packages/praxo_core>
