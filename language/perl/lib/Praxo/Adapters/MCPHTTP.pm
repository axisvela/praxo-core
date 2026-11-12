package Praxo::Adapters::MCPHTTP;

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP ();
use Praxo::Errors qw(praxo_error);

sub new {
    my ($class, %args) = @_;
    my $endpoint = $args{endpoint};
    praxo_error('MCP_TRANSPORT', 'mcp: endpoint is required')
        unless defined $endpoint && $endpoint ne '';
    my ($scheme, $host) = $endpoint =~ m{^(https?)://([^/:]+)}i;
    praxo_error('MCP_TRANSPORT', 'mcp: invalid HTTP endpoint')
        unless defined $scheme;
    if (lc($scheme) eq 'http' && !_loopback($host)) {
        praxo_error('MCP_TRANSPORT', 'mcp: HTTP endpoint must use HTTPS');
    }
    my $timeout = $args{timeout} // 30;
    return bless {
        endpoint => $endpoint,
        headers => $args{headers} // {},
        protocol_version => $args{protocol_version} // '2025-03-26',
        timeout => $timeout,
        session_id => '',
        next_id => 0,
        closed => 0,
        http => HTTP::Tiny->new(timeout => $timeout),
    }, $class;
}

sub request {
    my ($self, $method, $params) = @_;
    praxo_error('MCP_CLOSED', 'mcp: client is closed') if $self->{closed};
    $self->{next_id}++;
    my $id = $self->{next_id};
    my $message = {
        jsonrpc => '2.0',
        id => $id,
        method => $method,
        params => $params // {},
    };
    my ($status, $headers, $raw) = $self->_post(
        'POST',
        JSON::PP::encode_json($message),
        $self->_headers,
    );
    $self->_capture_session($headers);
    return {} if $status == 202 || $status == 204 || $raw =~ /\A\s*\z/;
    if ($status < 200 || $status >= 300) {
        praxo_error('MCP_TRANSPORT', "mcp: HTTP $status: " . substr($raw, 0, 512));
    }
    my $decoded = $self->_parse(
        $headers->{'content-type'} // '',
        $raw,
        $id,
    );
    if (ref($decoded->{error}) eq 'HASH') {
        my $detail = $decoded->{error}{message} // 'JSON-RPC error';
        praxo_error('MCP_RPC', "mcp: $method failed: $detail");
    }
    my $result = $decoded->{result};
    $result = {} unless ref($result) eq 'HASH';
    if (defined $result->{protocolVersion} && $result->{protocolVersion} ne '') {
        $self->{protocol_version} = $result->{protocolVersion};
    }
    return $result;
}

sub notify {
    my ($self, $method, $params) = @_;
    return if $self->{closed};
    $self->_post(
        'POST',
        JSON::PP::encode_json({
            jsonrpc => '2.0',
            method => $method,
            params => $params // {},
        }),
        $self->_headers,
    );
    return;
}

sub close {
    my ($self) = @_;
    return if $self->{closed};
    $self->{closed} = 1;
    return if $self->{session_id} eq '';
    eval {
        $self->_post('DELETE', '', $self->_headers);
        1;
    };
    return;
}

sub _headers {
    my ($self) = @_;
    my %headers = (
        'content-type' => 'application/json',
        'accept' => 'application/json, text/event-stream',
        'mcp-protocol-version' => $self->{protocol_version},
        %{ $self->{headers} },
    );
    $headers{'mcp-session-id'} = $self->{session_id}
        if $self->{session_id} ne '';
    return \%headers;
}

sub _capture_session {
    my ($self, $headers) = @_;
    my $session = $headers->{'mcp-session-id'};
    $self->{session_id} = $session
        if defined $session && $session ne '';
    return;
}

sub _post {
    my ($self, $method, $body, $headers) = @_;
    my $response = $self->{http}->request(
        $method,
        $self->{endpoint},
        {
            headers => $headers,
            content => $body,
        },
    );
    return (
        $response->{status},
        $response->{headers} // {},
        $response->{content} // '',
    );
}

sub _parse {
    my ($self, $content_type, $raw, $id) = @_;
    if (lc($content_type) =~ /text\/event-stream/) {
        return $self->_parse_sse($raw, $id);
    }
    my $decoded = eval { JSON::PP::decode_json($raw) };
    praxo_error('MCP_PROTOCOL', 'mcp: server sent invalid JSON')
        unless ref($decoded) eq 'HASH';
    return $decoded;
}

sub _parse_sse {
    my ($self, $raw, $id) = @_;
    my @messages;
    my @data;
    for my $line (split /\r\n|\n|\r/, $raw) {
        if ($line eq '') {
            if (@data) {
                push @messages, $self->_decode_message(join("\n", @data));
                @data = ();
            }
            next;
        }
        next if $line =~ /^:/;
        if ($line =~ /^data:(.*)$/) {
            my $value = $1;
            $value =~ s/^ //;
            push @data, $value;
        }
    }
    if (@data) {
        push @messages, $self->_decode_message(join("\n", @data));
    }
    praxo_error('MCP_PROTOCOL', 'mcp: response contained no message')
        unless @messages;
    for my $message (@messages) {
        return $message if defined $id && defined $message->{id} && $message->{id} == $id;
    }
    return $messages[0];
}

sub _decode_message {
    my ($self, $text) = @_;
    my $decoded = eval { JSON::PP::decode_json($text) };
    praxo_error('MCP_PROTOCOL', 'mcp: server sent invalid SSE JSON')
        unless ref($decoded) eq 'HASH';
    return $decoded;
}

sub _loopback {
    my ($host) = @_;
    return 0 unless defined $host;
    $host = lc $host;
    return 1 if $host eq 'localhost'
        || $host eq '127.0.0.1'
        || $host eq '::1'
        || $host eq '[::1]';
    return 1 if $host =~ /^127\./;
    return 0;
}

1;
