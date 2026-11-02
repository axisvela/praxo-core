# Publishing the Erlang Core

## Status

The Hex package is `praxo_core_erlang`. The `0.3.0` package and docs tarballs
were built locally:

```text
language/erlang/_build/default/lib/praxo_core/hex/praxo_core_erlang-0.3.0.tar
language/erlang/_build/default/lib/praxo_core/hex/praxo_core_erlang-0.3.0-docs.tar
```

They have **not** been uploaded because no Hex API key is configured.

Important release note: the pushed tag `erlang/v0.3.0` points at a commit whose
`src/praxo_core.app.src` still declared `vsn` `0.2.0`. The source tree now sets
`vsn` to `0.3.0`. Do not silently move the existing tag; prefer a fix-forward
`erlang/v0.3.1` release (or obtain explicit approval for a one-time tag
correction) and publish that version to Hex.

## Build

```bash
cd language/erlang
rebar3 hex build
```

Local gates:

```bash
python language/erlang/run-tests.py
python language/erlang/api-snapshot.py --check
```

## Publish

```bash
cd language/erlang
rebar3 hex publish
```

## Credentials and configuration

- Hex config: `C:\Users\hanhw1\.hex\hex.config`.
- `mix hex.config`/Hex tooling reports `api_key: nil`; configure with
  `mix hex.user auth` or set `HEX_API_KEY`. Do not commit the key.
- Hex package name comes from `src/praxo_core.app.src` (`pkg_name`), version
  from `vsn`.
- Network: the environment uses an HTTPS proxy with TLS interception. Export
  the trusted `mitmproxy` root from the Windows certificate store if Hex reports
  a certificate error; do not disable TLS verification.

## Verify

```bash
mix hex.info praxo_core_erlang
```

Registry: <https://hex.pm/packages/praxo_core_erlang>
