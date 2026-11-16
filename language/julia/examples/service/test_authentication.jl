using Base64

include(joinpath(@__DIR__, "authentication.jl"))
using .ServiceAuth

mutable struct ScriptedTransport
    status::Int
    body::String
    unavailable::Bool
    forms::Vector{Dict{String,String}}
    authorizations::Vector{Union{Nothing,String}}
end

ScriptedTransport(status, body) = ScriptedTransport(
    Int(status),
    String(body),
    false,
    Dict{String,String}[],
    Union{Nothing,String}[],
)

function (transport::ScriptedTransport)(url, form, authorization)
    push!(transport.forms, form)
    push!(transport.authorizations, authorization)
    transport.unavailable && throw(ServiceAuth.AuthError("identity provider unavailable"))
    return (transport.status, transport.body)
end

function body(fields...)
    return ServiceAuth.Json.stringify(Dict(pair for pair in fields))
end

endpoint = "https://id.example.com/introspect"
revocation_endpoint = "https://id.example.com/revoke"
now = 1_700_000_000

active = ScriptedTransport(200, body(
    "active" => true, "sub" => "user-1", "tenant" => "local", "exp" => now + 60,
))
authenticator = ServiceAuth.IntrospectionAuthenticator(
    active, endpoint; client_id = "client", client_secret = "secret",
)
principal = ServiceAuth.authenticate(authenticator, "Bearer opaque-token", now)
@assert principal !== nothing
@assert principal.subject == "user-1"
@assert principal.tenant == "local"
@assert principal.expires == now + 60
@assert active.forms[end]["token"] == "opaque-token"
@assert active.forms[end]["client_id"] == "client"
@assert active.forms[end]["client_secret"] == "secret"
@assert active.authorizations[end] == "Basic " * Base64.base64encode("client:secret")

blank_client = ScriptedTransport(200, body(
    "active" => true, "sub" => "user-1", "tenant" => "local", "exp" => now + 60,
))
blank_authenticator = ServiceAuth.IntrospectionAuthenticator(blank_client, endpoint)
@assert ServiceAuth.authenticate(blank_authenticator, "Bearer opaque-token", now) !== nothing
@assert blank_client.authorizations[end] === nothing

for authorization in (nothing, "", "Basic abc", "bearer token", "Token abc")
    @assert ServiceAuth.authenticate(authenticator, authorization, now) === nothing
end
@assert ServiceAuth.authenticate(authenticator, "Bearer ", now) === nothing
@assert ServiceAuth.authenticate(authenticator, "Bearer    ", now) === nothing

inactive = ScriptedTransport(200, body("active" => false))
inactive_authenticator = ServiceAuth.IntrospectionAuthenticator(inactive, endpoint)
@assert ServiceAuth.authenticate(inactive_authenticator, "Bearer opaque-token", now) === nothing

no_sub = ScriptedTransport(200, body(
    "active" => true, "tenant" => "local", "exp" => now + 60,
))
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(no_sub, endpoint), "Bearer opaque-token", now,
) === nothing

empty_sub = ScriptedTransport(200, body(
    "active" => true, "sub" => "", "tenant" => "local", "exp" => now + 60,
))
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(empty_sub, endpoint), "Bearer opaque-token", now,
) === nothing

no_tenant = ScriptedTransport(200, body(
    "active" => true, "sub" => "user-1", "exp" => now + 60,
))
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(no_tenant, endpoint), "Bearer opaque-token", now,
) === nothing

empty_tenant = ScriptedTransport(200, body(
    "active" => true, "sub" => "user-1", "tenant" => "", "exp" => now + 60,
))
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(empty_tenant, endpoint), "Bearer opaque-token", now,
) === nothing

for expiration in (now, now - 1)
    expired = ScriptedTransport(200, body(
        "active" => true, "sub" => "user-1", "tenant" => "local", "exp" => expiration,
    ))
    @assert ServiceAuth.authenticate(
        ServiceAuth.IntrospectionAuthenticator(expired, endpoint), "Bearer opaque-token", now,
    ) === nothing
end

malformed = ScriptedTransport(200, "{not json")
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(malformed, endpoint), "Bearer opaque-token", now,
) === nothing

denied = ScriptedTransport(401, body("active" => true))
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(denied, endpoint), "Bearer opaque-token", now,
) === nothing

unavailable = ScriptedTransport(200, "{}")
unavailable.unavailable = true
@assert ServiceAuth.authenticate(
    ServiceAuth.IntrospectionAuthenticator(unavailable, endpoint), "Bearer opaque-token", now,
) === nothing

custom = ScriptedTransport(200, body(
    "active" => true, "sub" => "user-1", "org" => "acme", "exp" => now + 60,
))
custom_authenticator = ServiceAuth.IntrospectionAuthenticator(
    custom, endpoint; tenant_claim = "org",
)
custom_principal = ServiceAuth.authenticate(custom_authenticator, "Bearer opaque-token", now)
@assert custom_principal !== nothing
@assert custom_principal.tenant == "acme"

revoker = ServiceAuth.RevocationClient(
    active, revocation_endpoint; client_id = "client", client_secret = "secret",
)
@assert ServiceAuth.revoke(revoker, "opaque-token") === true
@assert active.forms[end]["token"] == "opaque-token"
@assert active.forms[end]["token_type_hint"] == "access_token"

failed_revocation = ScriptedTransport(503, "{}")
failed_revoker = ServiceAuth.RevocationClient(failed_revocation, revocation_endpoint)
error = try
    ServiceAuth.revoke(failed_revoker, "opaque-token")
    nothing
catch caught
    caught
end
@assert error isa ServiceAuth.AuthError

unavailable_revocation = ScriptedTransport(200, "{}")
unavailable_revocation.unavailable = true
unavailable_revoker = ServiceAuth.RevocationClient(
    unavailable_revocation, revocation_endpoint,
)
error = try
    ServiceAuth.revoke(unavailable_revoker, "opaque-token")
    nothing
catch caught
    caught
end
@assert error isa ServiceAuth.AuthError

error = try
    ServiceAuth.revoke(revoker, "")
    nothing
catch caught
    caught
end
@assert error isa ServiceAuth.AuthError

println("Julia service auth tests passed")
