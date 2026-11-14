# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary failure when both fail.

```bash
fpc -Mobjfpc language/delphi/examples/provider-fallback/fallback.pas
./fallback
```

Expected output:

```text
Delphi provider fallback example passed
```
