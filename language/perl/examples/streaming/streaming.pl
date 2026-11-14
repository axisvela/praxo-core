use strict;
use warnings;

my @chunks = ('status: ', 'green');
my @received;
my $output = '';
for my $chunk (@chunks) {
    $output .= $chunk;
    push @received, $chunk;
}
die "deltas did not reconstruct the output\n"
    unless $output eq 'status: green'
        && join('', @received) eq $output
        && @received == @chunks;

print "Perl streaming example passed\n";
