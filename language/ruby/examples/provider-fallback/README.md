# Provider Fallback

This example wraps two Ruby Core models and uses the fallback only after the
primary fails. Both failures preserve the primary `MODEL_UNAVAILABLE` error.

```bash
ruby -I language/ruby/lib language/ruby/examples/provider-fallback/test_fallback.rb
```

Expected output:

```text
Ruby provider fallback tests passed
```
