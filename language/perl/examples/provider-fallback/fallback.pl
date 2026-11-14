use strict;
use warnings;

sub run_fallback {
    my ($primary_fails, $fallback_fails) = @_;
    return 'primary' unless $primary_fails;
    return 'fallback' unless $fallback_fails;
    return 'MODEL_UNAVAILABLE';
}

die "primary path failed\n"
    unless run_fallback(0, 0) eq 'primary';
die "fallback path failed\n"
    unless run_fallback(1, 0) eq 'fallback';
die "both-failure path failed\n"
    unless run_fallback(1, 1) eq 'MODEL_UNAVAILABLE';

print "Perl provider fallback example passed\n";
