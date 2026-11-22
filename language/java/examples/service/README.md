# HTTP Service

This example embeds published Maven `com.axisvela:praxo-core:0.7.0` in a
standard-library JDK HTTP service. The application supplies a principal and
tenant, restricts tools, and returns JSON.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
mvn -q compile exec:java
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The `X-Praxo-Principal` header is an application context stand-in, not
authentication. A production service must verify identity and derive the
principal and tenant from trusted context.

## OIDC/JWKS

Set `PRAXO_OIDC_ISSUER` and `PRAXO_OIDC_AUDIENCE` to verify RS256, RS384, or
RS512 JWTs from an external OIDC provider:

```bash
export PRAXO_OIDC_ISSUER=https://issuer.example.com
export PRAXO_OIDC_AUDIENCE=praxo-service
export PRAXO_OIDC_TENANT_CLAIM=tenant
# optional; discovered from the issuer when omitted
# export PRAXO_OIDC_DISCOVERY_URL=https://issuer.example.com/.well-known/openid-configuration
# export PRAXO_OIDC_JWKS_URL=https://issuer.example.com/.well-known/jwks.json
mvn -q compile exec:java
```

The verifier fetches provider metadata when `PRAXO_OIDC_JWKS_URL` is unset,
requires the metadata issuer to match, caches JWKS for five minutes, and
refreshes once on an unknown `kid`. It requires a valid signature, matching
`iss` and `aud`, a future integer `exp`, an optional `nbf` that is not in the
future, a non-empty `sub`, and the configured tenant claim. Discovery, JWKS,
timeout, invalid signature, unknown key, wrong issuer, wrong audience, expired
token, or missing claims deny the request. This is not key management,
revocation, or a hosted identity provider.

If both `PRAXO_INTROSPECTION_URL` and `PRAXO_OIDC_ISSUER` are set, introspection
takes precedence.

## Token Introspection

Set `PRAXO_INTROSPECTION_URL` to verify `Authorization: Bearer` tokens through
an RFC 7662 endpoint:

```bash
export PRAXO_INTROSPECTION_URL=https://issuer.example.com/introspect
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
export PRAXO_OIDC_TENANT_CLAIM=tenant
mvn -q compile exec:java
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer opaque-token' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The verifier requires `active: true`, `sub`, the configured tenant claim, and an
integer `exp` in the future. A timeout, non-200 response, inactive token,
missing claim, or expired `exp` denies the request.

## Token Revocation

```bash
export PRAXO_REVOCATION_URL=https://issuer.example.com/revoke
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
mvn -q compile exec:java -Dexec.args="--revoke-token $TOKEN"
```

Revocation is an application decision; the service does not revoke
automatically. OIDC/JWKS verification is available separately through
`PRAXO_OIDC_ISSUER`.

## Test

```bash
mvn -q compile exec:java -Dexec.args=--test
```

Expected output:

```text
service test: ok
```

On Windows hosts where the console `java` launcher hangs but `javaw` works, run
the compiled test with file redirection:

```powershell
javac -d build\java-service -cp language\java\target\classes `
  language\java\examples\service\src\main\java\service\*.java
javaw --add-modules jdk.httpserver `
  -cp "build\java-service;language\java\target\classes" `
  service.ServiceExample --test > build\java-auth.out
Get-Content build\java-auth.out
```

The test uses a fake model and loopback HTTP servers for introspection,
revocation, and OIDC discovery/JWKS; no external endpoint or identity provider
is required. It covers the active token, inactive token, missing expiration,
unavailable provider, revocation success, revocation failure, OIDC allow, wrong
audience, expired token, wrong issuer, unknown key, and unavailable provider.
On this Windows host the `java`/`javaw` launcher currently hangs before `main`;
compilation is verified but the runtime result is not recorded.
