# Publishing the Julia Core

## Status

Source tag `julia/v0.2.0` maps to Julia package `PraxoCore` version `0.2.0`.
The package is not yet in the General Registry.

## Build and validate

From the repository root:

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
```

The release workflow runs the same commands for `julia/v*` tags and manual
builds.

## Register in General

Registration uses JuliaRegistrator; no separate Julia account is required.

1. Install the Registrator GitHub app on `axisvela/praxo-core`.
2. Create or confirm the `julia/v0.2.0` tag.
3. Comment `@JuliaRegistrator register` on the commit or release issue.
4. Registrator opens a pull request against `JuliaRegistries/General`.
5. Respond to review and merge; then verify:

```julia
using Pkg
Pkg.add("PraxoCore")
```

The Project.toml UUID is fixed and must not change for an existing package.
