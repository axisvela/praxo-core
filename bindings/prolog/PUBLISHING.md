# Publishing the Prolog Bridge

Source tag `prolog/v0.1.1`. The bridge is not in the SWI-Prolog pack registry.

SWI-Prolog packs are Git repositories with `pack.pl` at the repository root.
Create a split mirror such as `axisvela/praxo-core-prolog` containing the pack
manifest, `praxo_bridge.pl`, `LICENSE`, and `README.md`. Keep `main/0` as the
executable entry point.

Run `python bindings/prolog/test_bridge.py`, push the split tag, then verify with
`pack_install(praxo_bridge)`. No separate account is required.
