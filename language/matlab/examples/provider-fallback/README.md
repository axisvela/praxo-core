# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary failure when both fail.

```bash
octave-cli --path language/matlab/examples/provider-fallback --eval fallback_example
```

Expected output:

```text
MATLAB provider fallback example passed
```
