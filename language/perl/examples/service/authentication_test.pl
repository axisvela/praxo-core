use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;
use MIME::Base64 qw(encode_base64);
use Test::More;
use ServiceAuth;

my $now = 1_700_000_000;
my $expected_basic = 'Basic ' . encode_base64('svc:secret', '');

sub scripted_transport {
    my (%options) = @_;
    my @calls;
    my $transport = sub {
        my ($url, $form, $authorization) = @_;
        push @calls, {
            url           => $url,
            form          => { %$form },
            authorization => $authorization,
        };
        die ServiceAuth::AuthError->new('unavailable') if $options{raise};
        return $options{result};
    };
    return ($transport, \@calls);
}

my $context = ServiceAuth::context_authenticator('tenant-a');
is_deeply(
    ServiceAuth::context_authenticate($context, 'user-1'),
    { subject => 'user-1', tenant => 'tenant-a', expires => undef },
    'context principal',
);
is(ServiceAuth::context_authenticate($context, undef), undef, 'context missing principal');
is(ServiceAuth::context_authenticate($context, ''), undef, 'context empty principal');

my $valid_body = '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":'
    . ($now + 60) . '}';

my ($transport, $calls) = scripted_transport(result => [200, $valid_body]);
my $auth = ServiceAuth::introspection_authenticator(
    transport     => $transport,
    endpoint      => 'https://idp.example/introspect',
    client_id     => 'svc',
    client_secret => 'secret',
);
my $principal = ServiceAuth::introspection_authenticate($auth, 'Bearer token-1', $now);
is_deeply(
    $principal,
    { subject => 'user-1', tenant => 'tenant-a', expires => $now + 60 },
    'introspection principal',
);
is(scalar @$calls, 1, 'introspection called transport once');
is($calls->[0]{url}, 'https://idp.example/introspect', 'introspection endpoint');
is($calls->[0]{form}{token}, 'token-1', 'introspection token');
is($calls->[0]{form}{client_id}, 'svc', 'introspection client id');
is($calls->[0]{form}{client_secret}, 'secret', 'introspection client secret');
is($calls->[0]{authorization}, $expected_basic, 'introspection basic auth');

my ($local_transport, $local_calls) = scripted_transport(raise => 1);
my $local_auth = ServiceAuth::introspection_authenticator(
    transport => $local_transport,
    endpoint  => 'https://idp.example/introspect',
);
is(ServiceAuth::introspection_authenticate($local_auth, undef, $now), undef,
    'missing bearer');
is(ServiceAuth::introspection_authenticate($local_auth, 'Basic token', $now), undef,
    'wrong auth scheme');
is(ServiceAuth::introspection_authenticate($local_auth, 'Bearer   ', $now), undef,
    'empty bearer token');
is(scalar @$local_calls, 0, 'local rejections do not call transport');

my @rejected_bodies = (
    '{"active":false,"sub":"user-1","tenant":"tenant-a","exp":' . ($now + 60) . '}',
    '{"active":true,"sub":"","tenant":"tenant-a","exp":' . ($now + 60) . '}',
    '{"active":true,"sub":"user-1","tenant":"","exp":' . ($now + 60) . '}',
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":' . $now . '}',
    '{"active":true,"sub":"user-1","tenant":"tenant-a"}',
    'not-json',
);

for my $body (@rejected_bodies) {
    my ($reject_transport) = scripted_transport(result => [200, $body]);
    my $reject_auth = ServiceAuth::introspection_authenticator(
        transport => $reject_transport,
        endpoint  => 'https://idp.example/introspect',
    );
    is(ServiceAuth::introspection_authenticate($reject_auth, 'Bearer token-1', $now),
        undef, 'rejected introspection body');
}

my ($status_transport) = scripted_transport(result => [500, $valid_body]);
my $status_auth = ServiceAuth::introspection_authenticator(
    transport => $status_transport,
    endpoint  => 'https://idp.example/introspect',
);
is(ServiceAuth::introspection_authenticate($status_auth, 'Bearer token-1', $now),
    undef, 'non-200 introspection');

my ($error_transport) = scripted_transport(raise => 1);
my $error_auth = ServiceAuth::introspection_authenticator(
    transport => $error_transport,
    endpoint  => 'https://idp.example/introspect',
);
is(ServiceAuth::introspection_authenticate($error_auth, 'Bearer token-1', $now),
    undef, 'transport error');

my $org_body = '{"active":true,"sub":"user-1","org":"org-a","exp":'
    . ($now + 60) . '}';
my ($org_transport) = scripted_transport(result => [200, $org_body]);
my $org_auth = ServiceAuth::introspection_authenticator(
    transport    => $org_transport,
    endpoint     => 'https://idp.example/introspect',
    tenant_claim => 'org',
);
is(
    ServiceAuth::introspection_authenticate($org_auth, 'Bearer token-1', $now)->{tenant},
    'org-a',
    'custom tenant claim',
);

my ($revocation_transport, $revocation_calls) =
    scripted_transport(result => [200, '']);
my $client = ServiceAuth::revocation_client(
    transport     => $revocation_transport,
    endpoint      => 'https://idp.example/revoke',
    client_id     => 'svc',
    client_secret => 'secret',
);
ok(ServiceAuth::revoke($client, 'token-1'), 'revocation result');
is(scalar @$revocation_calls, 1, 'revocation called transport once');
is($revocation_calls->[0]{form}{token}, 'token-1', 'revocation token');
is($revocation_calls->[0]{form}{token_type_hint}, 'access_token',
    'revocation token type hint');
is($revocation_calls->[0]{authorization}, $expected_basic, 'revocation basic auth');

my ($status_revocation_transport) = scripted_transport(result => [400, '']);
my $status_client = ServiceAuth::revocation_client(
    transport => $status_revocation_transport,
    endpoint  => 'https://idp.example/revoke',
);
my $status_error;
eval { ServiceAuth::revoke($status_client, 'token-1') };
$status_error = $@;
is(ref($status_error), 'ServiceAuth::AuthError', 'revocation non-200 error type');
is($status_error->message, 'token revocation failed', 'revocation non-200 message');

my ($raising_revocation_transport) = scripted_transport(raise => 1);
my $raising_client = ServiceAuth::revocation_client(
    transport => $raising_revocation_transport,
    endpoint  => 'https://idp.example/revoke',
);
my $raising_error;
eval { ServiceAuth::revoke($raising_client, 'token-1') };
$raising_error = $@;
is(ref($raising_error), 'ServiceAuth::AuthError', 'revocation transport error type');
is($raising_error->message, 'token revocation failed', 'revocation transport error message');

my ($empty_transport, $empty_calls) = scripted_transport(raise => 1);
my $empty_client = ServiceAuth::revocation_client(
    transport => $empty_transport,
    endpoint  => 'https://idp.example/revoke',
);
my $empty_error;
eval { ServiceAuth::revoke($empty_client, '') };
$empty_error = $@;
is(ref($empty_error), 'ServiceAuth::AuthError', 'revocation empty token error type');
is($empty_error->message, 'revocation token is required', 'revocation empty token message');
is(scalar @$empty_calls, 0, 'empty revocation does not call transport');

ok(ref(ServiceAuth::http_transport()) eq 'CODE', 'HTTP transport is callable');
require HTTP::Tiny;
is(
    HTTP::Tiny->www_form_urlencode({ token => 'token 1' }),
    'token=token+1',
    'HTTP transport form encoding',
);

done_testing();
