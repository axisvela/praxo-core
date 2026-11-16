# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```powershell
powershell -File language/powershell/examples/service/service.ps1
```

Expected output:

```text
PowerShell service example passed
```

## Service authentication

RFC 7662 introspection and RFC 7009 revocation use a caller-supplied scriptblock
as the transport seam.

- Module path: `language/powershell/examples/service/authentication.ps1`
- Test path: `language/powershell/examples/service/authentication.tests.ps1`
- Transport seam: scriptblock `($Url, $Form, $Authorization)` returning an
  object with `Status` and `Body`; pass `$null` for no authorization header.

```powershell
powershell -File language/powershell/examples/service/authentication.tests.ps1
```

Expected output:

```text
PowerShell service authentication tests passed
```

Verified locally with Windows PowerShell using a scripted transport; no live
identity provider is contacted.
