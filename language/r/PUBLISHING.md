# Publishing the R Core

## Status

Source tag `r/v0.9.0` maps to package `praxocore` version `0.9.0`. The package
is indexed by r-universe at <https://axisvela.r-universe.dev/praxocore>; the
current r-universe build is `0.7.1`. CRAN publication is not yet claimed.

## Build

From the repository root:

```bash
R CMD build language/r
R CMD check --no-manual --no-build-vignettes praxocore_0.9.0.tar.gz
```

`R CMD check` must finish without ERROR before submission. The package tests
run against the installed package when available and fall back to the repository
sources for local runs.

## r-universe

r-universe builds from the GitHub repository and the `language/r` subdirectory.
No separate account or secret is required. Push the source tag or update the
default branch, then check the package page and build logs:

<https://axisvela.r-universe.dev/praxocore>

## CRAN

CRAN does not require an account; submission uses the maintainer email in
`DESCRIPTION`. Before submitting:

1. Run `R CMD check --as-cran` and resolve ERRORs, WARNINGs, and avoidable NOTEs.
2. Add documentation entries for exported objects. The current package still
   reports the "all user-level objects should have documentation" warning.
3. Submit the checked tarball at <https://cran.r-project.org/submit.html> and
   respond to the confirmation email.

Do not submit while the check reports an ERROR or the package lacks documentation
for exported functions.
