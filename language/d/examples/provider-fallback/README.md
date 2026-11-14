# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary failure when both fail.

```bash
dmd -run language/d/examples/provider-fallback/fallback.d
```

Expected output:

```text
D provider fallback example passed
```
