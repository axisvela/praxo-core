# Independent R Consumer

This starter installs the published `praxocore` package from r-universe and
verifies an allow/deny governed tool path.

```r
install.packages("praxocore", repos = "https://axisvela.r-universe.dev")
source("starter.R")
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The starter uses a deterministic model. It does not prove live provider
behavior, authentic identity, durable approvals, or production readiness.
