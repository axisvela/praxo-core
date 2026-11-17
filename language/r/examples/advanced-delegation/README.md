# Advanced Delegation (R)

This example adds application-level governed delegation checks for the R Core.

```bash
Rscript language/r/examples/advanced-delegation/test_governance.R
```

Expected output:

```text
R governance: delegation checks passed (6)
```

It covers:

- child tool scope narrowing against the parent delegable scope;
- parent and child policy composition;
- child-count and depth limits;
- a shared cumulative budget across siblings;
- cancellation before effects;
- final-argument reauthorization after a middleware edit.

The checks use a deterministic model and the R source tree; they do not install a
package, call a provider, or prove production behavior. See
[multi-agent patterns](../../../../docs/guides/multi-agent.md) for the wider
delegation boundaries.
