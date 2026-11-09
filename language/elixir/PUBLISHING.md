# Publishing the Elixir Core

## Status

`praxo_core==0.4.0` is published from source tag `elixir/v0.4.0` with an
interactive 2FA OTP. Hex reports `0.4.0`, `0.3.0`, `0.2.0`, and `0.1.1` for
`praxo_core`. HexDocs are published at
<https://praxo-core.hexdocs.pm/0.4.0/> by
`.github/workflows/elixir-release.yml`. Source `0.4.1` and `api/0.4.1.txt` are
prepared; Hex publication is pending.

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

The `elixir-release` workflow runs the package and docs gates. A `publish`
target or `elixir/v*` tag uploads the package and HexDocs when the registry does
not already have the release. Configure the GitHub environment `hex` and
repository secret `HEX_API_KEY`.

For a local publish, authenticate once and run:

```bash
cd language/elixir
mix hex.user auth
mix hex.publish
mix hex.publish docs
```

Or set `HEX_API_KEY` for the command environment. Do not put the key in the
repository.

## Credentials and configuration

- Hex config: `C:\Users\hanhw1\.hex\hex.config`.
- `mix hex.config` currently reports `api_key: nil`. Configure it with
  `mix hex.user auth` or set `HEX_API_KEY`.
- HexDocs are published by `mix hex.publish` when `docs` is enabled.
- Network: the environment uses an HTTPS proxy with TLS interception. If Hex
  reports a certificate error, export the trusted `mitmproxy` root to
  `$HOME\.config\certs\mitmproxy-ca.pem` and set `HEX_CACERTS_PATH` in the same
  shell; do not disable TLS verification.

```powershell
$certDir = Join-Path $HOME '.config\certs'
New-Item -ItemType Directory -Force $certDir | Out-Null
$cert = Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object { $_.Subject -match 'mitmproxy' } | Select-Object -First 1
$pem = "-----BEGIN CERTIFICATE-----`n" +
  [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') +
  "`n-----END CERTIFICATE-----`n"
$env:HEX_CACERTS_PATH = Join-Path $certDir 'mitmproxy-ca.pem'
[IO.File]::WriteAllText($env:HEX_CACERTS_PATH, $pem, [Text.Encoding]::ASCII)
mix hex.config | Select-String cacerts
```

## Verify

```bash
mix hex.info praxo_core
```

Registry: <https://hex.pm/packages/praxo_core>
