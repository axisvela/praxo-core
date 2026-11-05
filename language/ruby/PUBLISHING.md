# Publishing the Ruby Core

## Status

`praxo-core` `0.4.1` is the current source release. The Ruby-specific source
repository is `axisvela/praxo-core-ruby`. RubyGems currently reports `0.4.0`,
`0.3.0`, `0.2.0`, and `0.1.0` until `0.4.1` is published.

## Build

```bash
cd language/ruby
gem build praxo-core.gemspec
```

The gem version comes from `language/ruby/VERSION`. The artifact is
`praxo-core-<version>.gem` and is not committed.

Before publishing, run the local gates:

```bash
ruby language/ruby/conformance/run.rb
ruby language/ruby/api-snapshot.rb --check
ruby language/ruby/tests/run.rb
```

## Publish

```bash
gem push language/ruby/praxo-core-0.3.0.gem
```

## Credentials and configuration

- RubyGems API key: `C:\Users\hanhw1\.local\share\gem\credentials`
  (reported by `gem env` as `CREDENTIALS FILE`). On other systems the usual
  path is `~/.gem/credentials`.
- The key is stored under `:rubygems_api_key`. Do not print or commit it.
- Network: this Windows environment uses an HTTPS proxy that terminates TLS.
  Export the trusted `mitmproxy` root from the Windows certificate store to
  `$HOME\.config\certs\mitmproxy-ca.pem` and set `SSL_CERT_FILE` for the push.
  Keep the CA outside the repository and temporary directories.

Example for the proxy-CA environment:

```powershell
$certDir = Join-Path $HOME '.config\certs'
New-Item -ItemType Directory -Force $certDir | Out-Null
$cert = Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object { $_.Subject -match 'mitmproxy' } | Select-Object -First 1
$pem = "-----BEGIN CERTIFICATE-----`n" +
  [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') +
  "`n-----END CERTIFICATE-----`n"
$ca = Join-Path $certDir 'mitmproxy-ca.pem'
[IO.File]::WriteAllText($ca, $pem, [Text.Encoding]::ASCII)
$env:SSL_CERT_FILE = $ca
gem push language/ruby/praxo-core-0.3.0.gem
```

## Verify

```bash
gem list -r praxo-core
```

Registry: <https://rubygems.org/gems/praxo-core/versions/0.3.0>
