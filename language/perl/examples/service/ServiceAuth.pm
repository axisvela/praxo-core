package ServiceAuth;

use strict;
use warnings;

use MIME::Base64 qw(encode_base64);
use JSON::PP ();
use Scalar::Util qw(looks_like_number);

sub context_authenticator {
    my ($tenant) = @_;
    return { tenant => $tenant };
}

sub context_authenticate {
    my ($auth, $principal) = @_;
    return undef unless defined $principal && length $principal;
    return {
        subject => $principal,
        tenant  => $auth->{tenant},
        expires => undef,
    };
}

sub introspection_authenticator {
    my (%options) = @_;
    my $tenant_claim = $options{tenant_claim} // 'tenant';
    $tenant_claim = 'tenant' unless length $tenant_claim;
    return {
        transport     => $options{transport},
        endpoint      => $options{endpoint},
        client_id     => $options{client_id} // '',
        client_secret => $options{client_secret} // '',
        tenant_claim  => $tenant_claim,
    };
}

sub introspection_authenticate {
    my ($auth, $authorization, $now) = @_;
    $now //= time;
    return undef unless defined $authorization
        && $authorization =~ /\ABearer (.*)\z/s;
    my $token = $1;
    $token =~ s/\A\s+|\s+\z//g;
    return undef unless length $token;

    my $form = {
        token         => $token,
        client_id     => $auth->{client_id},
        client_secret => $auth->{client_secret},
    };
    my $result = eval {
        $auth->{transport}->($auth->{endpoint}, $form, _basic_auth($auth));
    };
    return undef if $@ || !$result || $result->[0] != 200;

    my $payload = eval { JSON::PP->new->decode($result->[1]) };
    return undef if $@ || ref($payload) ne 'HASH';

    my $active = $payload->{active};
    return undef unless JSON::PP::is_bool($active) && $active;

    my $subject = $payload->{sub};
    my $tenant  = $payload->{ $auth->{tenant_claim} };
    my $expires = $payload->{exp};
    return undef unless defined $subject && !ref($subject) && length $subject;
    return undef unless defined $tenant && !ref($tenant) && length $tenant;
    return undef unless defined $expires
        && looks_like_number($expires)
        && $expires == int($expires)
        && $expires > $now;

    return {
        subject => $subject,
        tenant  => $tenant,
        expires => int($expires),
    };
}

sub revocation_client {
    my (%options) = @_;
    return {
        transport     => $options{transport},
        endpoint      => $options{endpoint},
        client_id     => $options{client_id} // '',
        client_secret => $options{client_secret} // '',
    };
}

sub revoke {
    my ($client, $token) = @_;
    die ServiceAuth::AuthError->new('revocation token is required')
        unless defined $token && length $token;

    my $form = {
        token           => $token,
        token_type_hint => 'access_token',
        client_id       => $client->{client_id},
        client_secret   => $client->{client_secret},
    };
    my $result = eval {
        $client->{transport}->($client->{endpoint}, $form, _basic_auth($client));
    };
    die ServiceAuth::AuthError->new('token revocation failed')
        if $@ || !$result || $result->[0] != 200;
    return 1;
}

sub http_transport {
    return \&_http_post_form;
}

sub _http_post_form {
    my ($url, $form, $authorization) = @_;
    require HTTP::Tiny;

    my $body = HTTP::Tiny->www_form_urlencode($form);
    my %headers = ('content-type' => 'application/x-www-form-urlencoded');
    $headers{authorization} = $authorization if defined $authorization;

    my $response = eval {
        HTTP::Tiny->new(timeout => 2)->post(
            $url,
            { headers => \%headers, content => $body },
        );
    };
    die ServiceAuth::AuthError->new('identity provider unavailable')
        if $@ || !$response || $response->{status} == 599;

    return [$response->{status}, $response->{content} // ''];
}

sub _basic_auth {
    my ($auth) = @_;
    return undef unless defined $auth->{client_id} && length $auth->{client_id};
    return 'Basic ' . encode_base64(
        "$auth->{client_id}:$auth->{client_secret}", ''
    );
}

package ServiceAuth::AuthError;

use overload '""' => sub { $_[0]{message} }, fallback => 1;

sub new {
    my ($class, $message) = @_;
    return bless { message => $message }, $class;
}

sub message {
    return $_[0]{message};
}

1;
