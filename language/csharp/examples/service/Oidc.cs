using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.ServiceExample;

public sealed class OidcAuthenticator : IRequestAuthenticator
{
    private static readonly Dictionary<string, HashAlgorithmName> Algorithms =
        new(StringComparer.Ordinal)
        {
            ["RS256"] = HashAlgorithmName.SHA256,
            ["RS384"] = HashAlgorithmName.SHA384,
            ["RS512"] = HashAlgorithmName.SHA512,
        };

    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(5);

    private readonly HttpClient _client;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly string _jwksUrl;
    private readonly string _discoveryUrl;
    private readonly string _tenantClaim;
    private readonly object _gate = new();

    private Dictionary<string, JwkKey>? _keys;
    private DateTimeOffset _keysFetched;
    private ProviderMetadata? _metadata;
    private DateTimeOffset _metadataFetched;

    public OidcAuthenticator(
        HttpClient client,
        string issuer,
        string audience,
        string jwksUrl,
        string discoveryUrl,
        string tenantClaim)
    {
        if (string.IsNullOrWhiteSpace(issuer))
        {
            throw new ArgumentException("issuer is required", nameof(issuer));
        }
        if (string.IsNullOrWhiteSpace(audience))
        {
            throw new ArgumentException("audience is required", nameof(audience));
        }
        _client = client;
        _issuer = issuer.TrimEnd('/');
        _audience = audience;
        _jwksUrl = jwksUrl;
        _discoveryUrl = discoveryUrl;
        _tenantClaim = string.IsNullOrWhiteSpace(tenantClaim) ? "tenant" : tenantClaim;
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
        var parts = token.Split('.');
        if (parts.Length != 3)
        {
            return null;
        }
        try
        {
            var header = DecodeObject(parts[0]);
            var algorithm = StringClaim(header, "alg");
            var kid = StringClaim(header, "kid");
            if (algorithm is null
                || !Algorithms.TryGetValue(algorithm, out var hash)
                || string.IsNullOrEmpty(kid))
            {
                return null;
            }
            var payload = DecodeObject(parts[1]);
            var issuer = StringClaim(payload, "iss");
            if (issuer is null || issuer.TrimEnd('/') != _issuer)
            {
                return null;
            }
            if (!AudienceMatches(payload["aud"], _audience))
            {
                return null;
            }
            var expires = LongClaim(payload, "exp");
            if (expires is null || expires <= now.ToUnixTimeSeconds())
            {
                return null;
            }
            var notBefore = LongClaim(payload, "nbf");
            if (notBefore is not null && notBefore > now.ToUnixTimeSeconds())
            {
                return null;
            }
            var subject = StringClaim(payload, "sub");
            var tenant = StringClaim(payload, _tenantClaim);
            if (string.IsNullOrEmpty(subject) || string.IsNullOrEmpty(tenant))
            {
                return null;
            }
            var key = FindKey(kid, algorithm, false)
                ?? FindKey(kid, algorithm, true);
            if (key is null)
            {
                return null;
            }
            if (!VerifySignature(
                    key,
                    hash,
                    parts[0] + "." + parts[1],
                    Base64UrlDecode(parts[2])))
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

    private JwkKey? FindKey(string kid, string algorithm, bool refresh)
    {
        lock (_gate)
        {
            if (_keys is null
                || refresh
                || DateTimeOffset.UtcNow - _keysFetched > CacheTtl)
            {
                var url = _jwksUrl;
                if (string.IsNullOrEmpty(url))
                {
                    url = MetadataLocked().JwksUrl;
                }
                _keys = FetchKeys(url);
                _keysFetched = DateTimeOffset.UtcNow;
            }
            if (!_keys.TryGetValue(kid, out var key))
            {
                return null;
            }
            if (key.Kind != "RSA"
                || (key.Use.Length > 0 && key.Use != "sig")
                || (key.Algorithm.Length > 0 && key.Algorithm != algorithm))
            {
                return null;
            }
            return key;
        }
    }

    private ProviderMetadata MetadataLocked()
    {
        if (_metadata is not null
            && DateTimeOffset.UtcNow - _metadataFetched <= CacheTtl)
        {
            return _metadata;
        }
        var url = string.IsNullOrEmpty(_discoveryUrl)
            ? _issuer + "/.well-known/openid-configuration"
            : _discoveryUrl;
        var body = FetchObject(url);
        var issuer = StringClaim(body, "issuer");
        if (issuer is null || issuer.TrimEnd('/') != _issuer)
        {
            throw new InvalidOperationException("invalid provider issuer");
        }
        var jwksUrl = StringClaim(body, "jwks_uri");
        if (string.IsNullOrEmpty(jwksUrl))
        {
            throw new InvalidOperationException("provider metadata is missing jwks_uri");
        }
        _metadata = new ProviderMetadata(issuer, jwksUrl);
        _metadataFetched = DateTimeOffset.UtcNow;
        return _metadata;
    }

    private Dictionary<string, JwkKey> FetchKeys(string url)
    {
        var body = FetchObject(url);
        if (body["keys"] is not JsonArray keys)
        {
            throw new InvalidOperationException("invalid JWKS");
        }
        var result = new Dictionary<string, JwkKey>(StringComparer.Ordinal);
        foreach (var item in keys)
        {
            if (item is not JsonObject key)
            {
                continue;
            }
            var kid = StringClaim(key, "kid");
            var kind = StringClaim(key, "kty");
            var modulus = StringClaim(key, "n");
            var exponent = StringClaim(key, "e");
            if (string.IsNullOrEmpty(kid)
                || string.IsNullOrEmpty(kind)
                || string.IsNullOrEmpty(modulus)
                || string.IsNullOrEmpty(exponent))
            {
                continue;
            }
            result[kid] = new JwkKey(
                kid,
                kind,
                StringClaim(key, "use") ?? "",
                StringClaim(key, "alg") ?? "",
                modulus,
                exponent);
        }
        return result;
    }

    private JsonObject FetchObject(string url)
    {
        using var response = _client.GetAsync(url).GetAwaiter().GetResult();
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException("identity provider unavailable");
        }
        var parsed = JsonNode.Parse(
            response.Content.ReadAsStringAsync().GetAwaiter().GetResult());
        return parsed as JsonObject
            ?? throw new InvalidOperationException("invalid provider response");
    }

    private static bool VerifySignature(
        JwkKey key,
        HashAlgorithmName hash,
        string signingInput,
        byte[] signature)
    {
        try
        {
            var modulus = Base64UrlDecode(key.Modulus);
            var exponent = Base64UrlDecode(key.Exponent);
            if (modulus.Length == 0 || exponent.Length == 0 || exponent.Length > 8)
            {
                return false;
            }
            using var rsa = RSA.Create();
            rsa.ImportParameters(new RSAParameters
            {
                Modulus = modulus,
                Exponent = exponent,
            });
            return rsa.VerifyData(
                Encoding.ASCII.GetBytes(signingInput),
                signature,
                hash,
                RSASignaturePadding.Pkcs1);
        }
        catch (Exception)
        {
            return false;
        }
    }

    private static JsonObject DecodeObject(string segment)
    {
        var parsed = JsonNode.Parse(Base64UrlDecode(segment));
        return parsed as JsonObject
            ?? throw new InvalidOperationException("invalid token");
    }

    private static string? StringClaim(JsonObject body, string name)
        => body[name] is JsonValue value && value.TryGetValue<string>(out var text)
            ? text
            : null;

    private static long? LongClaim(JsonObject body, string name)
        => body[name] is JsonValue value && value.TryGetValue<long>(out var number)
            ? number
            : null;

    private static bool AudienceMatches(JsonNode? value, string expected)
    {
        if (value is JsonValue single
            && single.TryGetValue<string>(out var audience))
        {
            return audience == expected;
        }
        if (value is JsonArray many)
        {
            foreach (var item in many)
            {
                if (item is JsonValue candidate
                    && candidate.TryGetValue<string>(out var candidateAudience)
                    && candidateAudience == expected)
                {
                    return true;
                }
            }
        }
        return false;
    }

    private static byte[] Base64UrlDecode(string value)
    {
        var text = value.Replace('-', '+').Replace('_', '/');
        text = (text.Length % 4) switch
        {
            2 => text + "==",
            3 => text + "=",
            _ => text,
        };
        return Convert.FromBase64String(text);
    }

    private sealed record JwkKey(
        string Kid,
        string Kind,
        string Use,
        string Algorithm,
        string Modulus,
        string Exponent);

    private sealed record ProviderMetadata(string Issuer, string JwksUrl);
}
