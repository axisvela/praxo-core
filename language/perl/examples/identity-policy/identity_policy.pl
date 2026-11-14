use strict;
use warnings;

sub authorize {
    my ($principal, $tool, $tenant) = @_;
    return 0 unless defined $principal;
    return 0 unless $principal->{active};
    return 0 unless $principal->{role} eq 'operator';
    return 0 unless $principal->{tenant} eq $tenant;
    return $tool eq 'record';
}

my $operator = { tenant => 'acme', role => 'operator', active => 1 };
die "operator denied\n" unless authorize($operator, 'record', 'acme');
die "viewer allowed\n"
    if authorize({ %$operator, role => 'viewer' }, 'record', 'acme');
die "tenant mismatch allowed\n" if authorize($operator, 'record', 'other');
die "missing principal allowed\n" if authorize(undef, 'record', 'acme');

print "Perl identity policy example passed\n";
