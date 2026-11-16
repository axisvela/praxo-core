module ServiceAuth

using Base64

include(joinpath(@__DIR__, "..", "..", "src", "Json.jl"))
using .Json

export Principal, AuthError, IntrospectionAuthenticator, RevocationClient
export authenticate, revoke

struct Principal
    subject::String
    tenant::String
    expires::Int
end

struct AuthError <: Exception
    message::String
end

Base.showerror(io::IO, error::AuthError) = print(io, error.message)

struct IntrospectionAuthenticator
    transport::Any
    endpoint::String
    client_id::String
    client_secret::String
    tenant_claim::String
end

function IntrospectionAuthenticator(
    transport, endpoint;
    client_id = "", client_secret = "", tenant_claim = "tenant",
)
    claim = isempty(tenant_claim) ? "tenant" : String(tenant_claim)
    return IntrospectionAuthenticator(
        transport,
        String(endpoint),
        String(client_id),
        String(client_secret),
        claim,
    )
end

struct RevocationClient
    transport::Any
    endpoint::String
    client_id::String
    client_secret::String
end

function RevocationClient(transport, endpoint; client_id = "", client_secret = "")
    return RevocationClient(
        transport, String(endpoint), String(client_id), String(client_secret),
    )
end

function basic_auth(client_id::String, client_secret::String)
    isempty(client_id) && return nothing
    return "Basic " * Base64.base64encode(client_id * ":" * client_secret)
end

function authenticate(
    authenticator::IntrospectionAuthenticator, authorization, now::Integer,
)
    authorization isa AbstractString || return nothing
    startswith(authorization, "Bearer ") || return nothing
    length(authorization) > 7 || return nothing
    token = strip(SubString(authorization, 8))
    isempty(token) && return nothing
    form = Dict(
        "token" => String(token),
        "client_id" => authenticator.client_id,
        "client_secret" => authenticator.client_secret,
    )
    status = 0
    body = ""
    try
        response = authenticator.transport(
            authenticator.endpoint,
            form,
            basic_auth(authenticator.client_id, authenticator.client_secret),
        )
        response isa Tuple || return nothing
        length(response) == 2 || return nothing
        status = response[1]
        body = response[2]
    catch
        return nothing
    end
    status == 200 || return nothing
    payload = try
        Json.parse_json(String(body))
    catch
        return nothing
    end
    payload isa AbstractDict || return nothing
    Json.getbool(payload, "active", false) === true || return nothing
    subject = Json.getstring(payload, "sub", nothing)
    tenant = Json.getstring(payload, authenticator.tenant_claim, nothing)
    subject isa AbstractString && !isempty(subject) || return nothing
    tenant isa AbstractString && !isempty(tenant) || return nothing
    raw_expires = Json.getvalue(payload, "exp", nothing)
    raw_expires isa Integer && !(raw_expires isa Bool) || return nothing
    raw_expires > now || return nothing
    return Principal(String(subject), String(tenant), Int(raw_expires))
end

function revoke(client::RevocationClient, token::AbstractString)
    isempty(token) && throw(AuthError("revocation token is required"))
    form = Dict(
        "token" => String(token),
        "token_type_hint" => "access_token",
        "client_id" => client.client_id,
        "client_secret" => client.client_secret,
    )
    response = try
        client.transport(
            client.endpoint,
            form,
            basic_auth(client.client_id, client.client_secret),
        )
    catch
        throw(AuthError("token revocation failed"))
    end
    response isa Tuple && length(response) == 2 ||
        throw(AuthError("token revocation failed"))
    response[1] == 200 || throw(AuthError("token revocation failed"))
    return true
end

end
