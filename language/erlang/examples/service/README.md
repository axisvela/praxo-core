# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Erlang HTTP server.

```bash
escript language/erlang/examples/service/service.escript
```

Expected output:

```text
Erlang service example passed
```

## Authentication

`authentication.erl` adds RFC 7662 introspection and RFC 7009 revocation with a
caller-supplied transport. It requires OTP 27 or newer for the built-in `json`
module. The example remains a request handler and does not include OIDC/JWKS.

```bash
mkdir -p build
erlc -o build language/erlang/examples/service/authentication.erl language/erlang/examples/service/authentication_test.erl
erl -noshell -pa build -s authentication_test main -s init stop
```

Expected output:

```text
Erlang service auth tests passed
```
