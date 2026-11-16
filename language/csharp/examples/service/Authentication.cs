using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.ServiceExample;

public sealed record AuthenticatedPrincipal(string Subject, string Tenant, long Expires);

public interface IRequestAuthenticator
{
    AuthenticatedPrincipal? Authenticate(
        string? principal,
        string? authorization,
        DateTimeOffset now);
}

public sealed class ContextAuthenticator : IRequestAuthenticator
{
    private readonly string _tenant;

    public ContextAuthenticator(string tenant)
    {
        _tenant = tenant;
    }

    public AuthenticatedPrincipal? Authenticate(
        string? principal,
        string? authorization,
        DateTimeOffset now)
    {
        if (string.IsNullOrEmpty(principal))
        {
            return null;
        }
        return new AuthenticatedPrincipal(principal, _tenant, long.MaxValue);
    }
}

public sealed class IntrospectionAuthenticator : IRequestAuthenticator
{
    private readonly HttpClient _client;
    private readonly string _endpoint;
    private readonly string _clientId;
    private readonly string _clientSecret;
    private readonly string _tenantClaim;

    public IntrospectionAuthenticator(
        HttpClient client,
        string endpoint,
        string clientId,
        string clientSecret,
        string tenantClaim)
    {
        _client = client;
        _endpoint = endpoint;
        _clientId = clientId;
        _clientSecret = clientSecret;
        _tenantClaim = string.IsNullOrEmpty(tenantClaim) ? "tenant" : tenantClaim;
    }

    public AuthenticatedPrincipal? Authenticate(
        string? principal,
        string? authorization,
        DateTimeOffset now)
    {
        if (string.IsNullOrEmpty(authorization)
            || !authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }
        var token = authorization["Bearer ".Length..].Trim();
        if (token.Length == 0)
        {
            return null;
        }
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, _endpoint)
            {
                Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["token"] = token,
                    ["client_id"] = _clientId,
                    ["client_secret"] = _clientSecret,
                }),
            };
            if (!string.IsNullOrEmpty(_clientId))
            {
                var raw = Encoding.UTF8.GetBytes($"{_clientId}:{_clientSecret}");
                request.Headers.Authorization = new AuthenticationHeaderValue(
                    "Basic", Convert.ToBase64String(raw));
            }
            using var response = _client.SendAsync(request).GetAwaiter().GetResult();
            if (!response.IsSuccessStatusCode)
            {
                return null;
            }
            var body = JsonNode.Parse(
                response.Content.ReadAsStringAsync().GetAwaiter().GetResult()) as JsonObject;
            if (body?["active"]?.GetValue<bool>() != true)
            {
                return null;
            }
            var subject = body["sub"]?.GetValue<string>();
            var tenant = body[_tenantClaim]?.GetValue<string>();
            var expires = body["exp"]?.GetValue<long>();
            if (string.IsNullOrEmpty(subject)
                || string.IsNullOrEmpty(tenant)
                || expires is null
                || expires <= now.ToUnixTimeSeconds())
            {
                return null;
            }
            return new AuthenticatedPrincipal(subject, tenant, expires.Value);
        }
        catch (Exception)
        {
            return null;
        }
    }
}

public static class RevocationClient
{
    public static async Task RevokeAsync(
        string token,
        HttpClient client,
        string endpoint,
        string clientId,
        string clientSecret,
        string tokenTypeHint = "access_token")
    {
        if (string.IsNullOrEmpty(token))
        {
            throw new ArgumentException("revocation token is required", nameof(token));
        }
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["token"] = token,
                ["token_type_hint"] = tokenTypeHint,
                ["client_id"] = clientId,
                ["client_secret"] = clientSecret,
            }),
        };
        if (!string.IsNullOrEmpty(clientId))
        {
            var raw = Encoding.UTF8.GetBytes($"{clientId}:{clientSecret}");
            request.Headers.Authorization = new AuthenticationHeaderValue(
                "Basic", Convert.ToBase64String(raw));
        }
        using var response = await client.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException("token revocation failed");
        }
    }
}
