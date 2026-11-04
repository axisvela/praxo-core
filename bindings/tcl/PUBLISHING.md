# Publishing the Tcl Bridge

Source tag `tcl/v0.1.0`. The bridge is not published to TEA or another Tcl
package repository.

Tcl packages need a loadable package and `pkgIndex.tcl`, not only an executable
script. Create a split mirror such as `axisvela/praxo-core-tcl`, expose the
bridge as a package command, and add a TEA/teapot manifest if targeting a Tcl
package repository.

Run `python bindings/tcl/test_bridge.py`, tag the split mirror, then verify with
`package require praxo`.
