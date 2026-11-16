# Service authentication boundary

Status: source-level boundary, unverified: toolchain absent. GnuCOBOL
(`cobc`) is not installed on this workstation, so no COBOL authentication
program or executable test is claimed to build or pass.

## Scope

This page defines the RFC 7662 introspection and RFC 7009 revocation boundary
for the COBOL service example. It is intentionally a boundary rather than a
runtime module. `authentication.cpy` provides the principal and request records
so a host program can bind to an external identity-provider transport without
changing the record layout later.

## Current repository capabilities

- JSON parsing and generation exist in `language/cobol/src/json-parse.cob`,
  `language/cobol/src/json-generate.cob`, and `language/cobol/copy/json.cpy`.
- The JSON document is a flat node table. Field selection for `active`, `sub`,
  `exp`, and a configurable tenant claim still needs a new traversal routine.
- No HTTP client, TLS stack, `Authorization` header parser, form encoder, or
  Base64 encoder is provided by this repository.
- COBOL has no function values. A caller-supplied transport is therefore a
  program name invoked with `CALL`, not a closure or function handle. This
  mirrors the existing provider transport-program field, for example
  `px-anthropic-transport-program` in `language/cobol/copy/anthropic-call.cpy`.

## Required transport seam

The host supplies a program that performs the HTTPS POST and returns one
`px-auth-transport-result`. The authentication logic must not open a socket
itself.

Introspection call:

```text
CALL "provider-introspect" USING
    px-auth-introspection-request
    px-auth-transport-result
```

The transport receives these form fields:

```text
token=<bearer token>
client_id=<px-auth-client-id>
client_secret=<px-auth-client-secret>
```

The transport adds `Authorization: Basic base64(client_id:client_secret)` only
when `px-auth-client-id` is not spaces. It must return HTTP status in
`px-auth-status`, the response body in `px-auth-body` plus
`px-auth-body-length`, and a non-space `px-auth-error` for any transport
failure.

Revocation call:

```text
CALL "provider-revoke" USING
    px-auth-revocation-request
    px-auth-transport-result
```

The revocation transport receives these form fields:

```text
token=<px-auth-token>
token_type_hint=access_token
client_id=<px-auth-client-id>
client_secret=<px-auth-client-secret>
```

## Required authentication behavior

`authenticate` accepts an `Authorization` value, the request endpoint, client
credentials, a tenant claim name defaulting to `tenant`, and the current epoch
seconds.

Accept only when all of the following hold:

1. The authorization value starts with the exact prefix `Bearer `.
2. The remaining trimmed token is non-empty.
3. The introspection transport reports status 200.
4. The body parses as a JSON object.
5. `active` is the JSON boolean `true`.
6. `sub` is a non-empty string.
7. The configured tenant claim is a non-empty string.
8. `exp` is an integer strictly greater than the current epoch seconds.

Return `px-auth-valid = 0` for a missing or wrong scheme, empty token, transport
error, non-200 response, malformed JSON, non-boolean `active`, missing or empty
`sub`, missing or empty tenant, non-integer `exp`, and an expired token. Fail
closed. Map an accepted subject, tenant, and expiry into `px-auth-principal` and
set `px-auth-valid = 1`.

`revoke` accepts a token and fails closed on an empty token, transport error,
or any non-200 status. It must send `token_type_hint=access_token`.

## Integration steps

1. Copy `authentication.cpy` into the service program's data division.
2. Implement `provider-introspect` and `provider-revoke` in the host HTTP
   runtime, or adapt an existing HTTP service runtime to the two CALL shapes.
3. Add a COBOL authentication program that fills the records, invokes the
   transport, applies the acceptance rules above, and returns the principal.
4. Add deterministic tests with stand-in transport programs that return scripted
   status and body values. Do not use a live identity provider.

## Verification that would be run

```bash
cd language/cobol
python run-tests.py
python examples/service/build.py
```

These commands were not executed. No authentication runtime module or test is
added here, so this boundary is explicitly unverified rather than a claimed
implementation.
