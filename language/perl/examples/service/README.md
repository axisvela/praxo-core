# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
perl language/perl/examples/service/service.pl
```

Expected output:

```text
Perl service example passed
```

## Authentication

`ServiceAuth.pm` adds RFC 7662 introspection and RFC 7009 revocation with a
caller-supplied transport. `http_transport` uses `HTTP::Tiny`. The example
remains a request handler and does not include OIDC/JWKS.

```bash
perl language/perl/examples/service/authentication_test.pl
```

Expected output ends with:

```text
1..37
```
