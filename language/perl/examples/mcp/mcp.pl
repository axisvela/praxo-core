use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::Adapters::MCP ();

my $client = Praxo::Adapters::MCP->new(
    transport => sub {
        my ($method, $params) = @_;
        if ($method eq 'initialize') {
            return { protocolVersion => '2024-11-05', serverInfo => { name => 'example-mcp' } };
        }
        if ($method eq 'tools/list') {
            return { tools => [{ name => 'echo' }, { name => 'add' }] };
        }
        if ($method eq 'tools/call') {
            return { structuredContent => { sum => 5 } };
        }
        die "unexpected method $method\n";
    },
);
$client->start;
my $tools = $client->list_tools;
my $result = $client->call_tool('add', {});
$client->close;

die "mcp example failed\n"
    unless join(',', map { $_->{name} } @$tools) eq 'echo,add'
        && $result->{sum} == 5;

print "Perl MCP example passed\n";
