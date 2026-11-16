# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any COBOL HTTP server.

```bash
python language/cobol/examples/service/build.py
```

Expected output:

```text
COBOL service example passed
```

## Authentication

RFC 7662 introspection and RFC 7009 revocation are documented at the source
level because this repository has no COBOL HTTP/TLS transport:

- Boundary and contract: `language/cobol/examples/service/AUTHENTICATION-BOUNDARY.md`
- Principal and request records: `language/cobol/examples/service/authentication.cpy`

No authentication runtime module or executable test is provided. Test command:
none. unverified: toolchain absent (GnuCOBOL `cobc` is not installed).
