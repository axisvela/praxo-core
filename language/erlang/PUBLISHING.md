# Publishing the Erlang Core

## Status

The Hex package is `praxo_core_erlang`. `0.4.0` is published from source tag
`erlang/v0.4.0` with an interactive 2FA OTP. Hex reports `0.4.0`, `0.3.1`,
`0.2.0`, and `0.1.1`.

`erlang/v0.3.0` remains a historical tag with stale `app.src` metadata (`0.2.0`);
do not publish a package from that tag.

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
proxy-CA environment, export the `mitmproxy` root to
`$HOME\.config\certs\mitmproxy-ca.pem` and set `HEX_CACERTS_PATH` in the same
shell before running Hex commands. Do not keep the CA in a temporary directory.

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
