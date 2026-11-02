# Publishing the Erlang Core

## Status

The Hex package is `praxo_core_erlang`. `0.3.1` is the fix-forward release and
is published on Hex. The missing `0.2.0` package is built in the detached
worktree:

```text
build/release/erlang-0.2.0/language/erlang/_build/default/lib/praxo_core/hex/praxo_core_erlang-0.2.0.tar
```

`erlang/v0.3.0` remains a historical tag with stale `app.src` metadata (`0.2.0`);
do not publish a package from that tag. Use `0.3.1` for the 0.3 line.

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

The Hex CLI requires an authenticated account and a current 2FA OTP. In the
proxy-CA environment, set `HEX_CACERTS_PATH` to the exported `mitmproxy` CA
before running Hex commands.

## Credentials and configuration

- Hex config: `C:\Users\hanhw1\.hex\hex.config`.
- Authentication is verified with `mix hex.user whoami`; it returns
  `hanhhuiwen` when `HEX_CACERTS_PATH` points at the proxy CA.
- Do not commit the API key or OTP.
- Hex package name comes from `src/praxo_core.app.src` (`pkg_name`), version
  from `vsn`.

## Verify

```bash
mix hex.info praxo_core_erlang
```

Registry: <https://hex.pm/packages/praxo_core_erlang>
