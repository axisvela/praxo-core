use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::Runtime;

my $allow = Praxo::Runtime::CheckpointAllowlist->new;
$allow->register('order');
my $data = $allow->marshal('order', { value => 'x' });
my $decoded = $allow->unmarshal($data);
die "checkpoint payload did not round trip\n"
    unless ref($decoded) eq 'HASH' && $decoded->{value} eq 'x';

print "Perl checkpoint example passed\n";
