use strict;
use warnings;

sub handle {
    my ($method, $path, $principal, $body) = @_;
    return (200, '{"status":"ok"}') if $method eq 'GET' && $path eq '/healthz';
    return (404, '{"error":"not found"}')
        unless $method eq 'POST' && $path eq '/run';
    return (401, '{"error":"missing X-Praxo-Principal"}')
        unless defined $principal && length $principal;
    return (400, '{"error":"prompt is required"}')
        unless index($body, '"prompt"') >= 0;
    return (200, '{"output":"hello from the service"}');
}

my ($status) = handle('GET', '/healthz', undef, '');
die "health failed\n" unless $status == 200;
($status) = handle('POST', '/run', undef, '{"prompt":"hi"}');
die "missing principal accepted\n" unless $status == 401;
my ($code, $response) = handle('POST', '/run', 'user-1', '{"prompt":"hi"}');
die "run failed\n"
    unless $code == 200 && index($response, 'hello from the service') >= 0;

print "Perl service example passed\n";
