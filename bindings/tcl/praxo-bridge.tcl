#!/usr/bin/env tclsh

set script_dir [file dirname [info script]]
set root [file normalize [file join $script_dir .. ..]]

if {[info exists ::env(PRAXO_BRIDGE_BIN)] && $::env(PRAXO_BRIDGE_BIN) ne ""} {
    set command [list $::env(PRAXO_BRIDGE_BIN)]
} else {
    set command [list go run [file join $root cmd praxo-bridge]]
}

set input [read stdin]
set status [catch {
    exec {*}$command {*}$argv << $input >@ stdout 2>@ stderr
} message options]

if {$status} {
    if {[dict exists $options -errorcode]} {
        set code [dict get $options -errorcode]
        if {[lindex $code 0] eq "CHILDSTATUS"} {
            exit [lindex $code 2]
        }
    }
    puts stderr $message
    exit 1
}

exit 0
