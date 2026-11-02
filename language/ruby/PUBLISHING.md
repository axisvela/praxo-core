# Publishing the Ruby Core

## Status

`praxo-core` `0.3.0` was published to RubyGems from source tag `ruby/v0.3.0`.

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
  `build/mitmproxy-ca.pem` and set `SSL_CERT_FILE` for the push. The CA file is
  a local build artifact and is not committed.

Example for the proxy-CA environment:

```powershell
$cert = Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object { $_.Subject -match 'mitmproxy' } | Select-Object -First 1
$pem = "-----BEGIN CERTIFICATE-----`n" +
  [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') +
  "`n-----END CERTIFICATE-----`n"
[IO.File]::WriteAllText("$PWD\build\mitmproxy-ca.pem", $pem)
$env:SSL_CERT_FILE = "$PWD\build\mitmproxy-ca.pem"
gem push language/ruby/praxo-core-0.3.0.gem
```

## Verify

```bash
gem list -r praxo-core
```

Registry: <https://rubygems.org/gems/praxo-core/versions/0.3.0>
