# Publishing the Julia Core

## Status

Source tag `julia/v0.9.0` maps to Julia package `PraxoCore` version `0.9.0`.
The package is mirrored at `axisvela/praxo-core-Julia` tag `0.9.0`. The General
Registry registration PR now targets `0.9.0`:
<https://github.com/JuliaRegistries/General/pull/176393>; review is pending.

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
The package is mirrored at `axisvela/praxo-core-Julia` with tag `0.9.0`.

1. Install the Registrator GitHub app on `axisvela/praxo-core-Julia`.
2. Comment `@JuliaRegistrator register` on the mirror commit.
3. Registrator opens a pull request against `JuliaRegistries/General`.
4. Respond to review and merge; then verify:

```julia
using Pkg
Pkg.add("PraxoCore")
```

The Project.toml UUID is fixed and must not change for an existing package.
