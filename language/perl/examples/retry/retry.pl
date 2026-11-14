use strict;
use warnings;

sub run_retry {
    my ($failures, $max) = @_;
    for my $attempt (1 .. $max) {
        return ('status: green', $attempt) if $attempt > $failures;
    }
    return (undef, 'MODEL_UNAVAILABLE', $max);
}

my ($output, $calls) = run_retry(2, 3);
die "transient retry failed\n" unless defined $output && $calls == 3;
my ($failed, $code, $exhausted) = run_retry(3, 3);
die "exhausted retry failed\n"
    unless !defined $failed && $code eq 'MODEL_UNAVAILABLE' && $exhausted == 3;

print "Perl retry example passed\n";
