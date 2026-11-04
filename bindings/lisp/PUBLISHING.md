# Publishing the Lisp Bridge

Source tag `lisp/v0.1.0`. The bridge is not in Quicklisp.

Quicklisp needs an ASDF system. The current file is an executable script that
calls `(main)` at load time. Create a split mirror such as
`axisvela/praxo-core-lisp` with `praxo-bridge.asd`, reusable functions in
`src/bridge.lisp`, an executable entry point in `main.lisp`, `LICENSE`, and
`README.md`.

Run `python bindings/lisp/test_bridge.py`, tag the split mirror, submit the
project to Quicklisp, and verify `(ql:quickload "praxo-bridge")`. No separate
Quicklisp account is required.
