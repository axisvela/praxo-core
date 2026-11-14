use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::JsonSchema;

my $schema = {
    type => 'object',
    required => ['name'],
    properties => { name => { type => 'string' } },
};

die "valid output was rejected\n"
    if @{ Praxo::JsonSchema::validate($schema, { name => 'ok' }) };
die "invalid output was accepted\n"
    unless @{ Praxo::JsonSchema::validate($schema, {}) };

print "Perl structured output example passed\n";
