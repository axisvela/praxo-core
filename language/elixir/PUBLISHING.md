# Publishing the Elixir Core

## Status

Source tags `elixir/v0.2.0` and `elixir/v0.3.0` are valid. Their Hex packages
were built in detached worktrees:

```text
build/release/elixir-0.2.0/language/elixir/praxo_core-0.2.0.tar
build/release/elixir-0.3.0/language/elixir/praxo_core-0.3.0.tar
```

Hex now requires a 2FA OTP at publish time. The Mix task prompts interactively,
so the packages must be published from a terminal (or with a supported OTP
mechanism). Hex reports only `0.1.1` for `praxo_core` until these are uploaded.

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
