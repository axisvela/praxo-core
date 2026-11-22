using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.ServiceExample;

internal static class OidcTests
{
    public static void Run()
    {
        using var key = RSA.Create(2048);
        var provider = new LoopbackProvider(Jwks(key, "test-key"));
        var now = DateTimeOffset.UtcNow;
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var verifier = new OidcAuthenticator(
            client, provider.Issuer, "praxo-service", "", "", "tenant");
        try
        {
            var allowed = verifier.Authenticate(
                null,
                "Bearer " + SignJwt(
                    key,
                    "test-key",
                    Claims(
                        provider.Issuer,
                        "praxo-service",
                        "user-1",
                        "local",
                        now.AddMinutes(1).ToUnixTimeSeconds())),
                now);
            if (allowed is null
                || allowed.Subject != "user-1"
                || allowed.Tenant != "local")
            {
                throw new InvalidOperationException("OIDC discovery/JWKS allow path failed");
            }

            var wrongAudience = verifier.Authenticate(
                null,
                "Bearer " + SignJwt(
                    key,
                    "test-key",
                    Claims(
                        provider.Issuer,
                        "other-service",
                        "user-1",
                        "local",
                        now.AddMinutes(1).ToUnixTimeSeconds())),
                now);
            if (wrongAudience is not null)
            {
                throw new InvalidOperationException("wrong OIDC audience was accepted");
            }

            var expired = verifier.Authenticate(
                null,
                "Bearer " + SignJwt(
                    key,
                    "test-key",
                    Claims(
                        provider.Issuer,
                        "praxo-service",
                        "user-1",
                        "local",
                        now.AddMinutes(-1).ToUnixTimeSeconds())),
                now);
            if (expired is not null)
            {
                throw new InvalidOperationException("expired OIDC token was accepted");
            }

            var wrongIssuer = verifier.Authenticate(
                null,
                "Bearer " + SignJwt(
                    key,
                    "test-key",
                    Claims(
                        "https://wrong.example.com",
                        "praxo-service",
                        "user-1",
                        "local",
                        now.AddMinutes(1).ToUnixTimeSeconds())),
                now);
            if (wrongIssuer is not null)
            {
                throw new InvalidOperationException("wrong OIDC issuer was accepted");
            }

            var unknownKey = verifier.Authenticate(
                null,
                "Bearer " + SignJwt(
                    key,
                    "other-key",
                    Claims(
                        provider.Issuer,
                        "praxo-service",
                        "user-1",
                        "local",
                        now.AddMinutes(1).ToUnixTimeSeconds())),
                now);
            if (unknownKey is not null)
            {
                throw new InvalidOperationException("unknown OIDC key was accepted");
            }
        }
        finally
        {
            provider.Dispose();
        }

        var unavailable = new OidcAuthenticator(
            client, provider.Issuer, "praxo-service", "", "", "tenant").Authenticate(
            null,
            "Bearer " + SignJwt(
                key,
                "test-key",
                Claims(
                    provider.Issuer,
                    "praxo-service",
                    "user-1",
                    "local",
                    now.AddMinutes(1).ToUnixTimeSeconds())),
            now);
        if (unavailable is not null)
        {
            throw new InvalidOperationException("unavailable OIDC provider was accepted");
        }
    }

    private static JsonObject Claims(
        string issuer,
        string audience,
        string subject,
        string tenant,
        long expires)
        => new()
        {
            ["iss"] = issuer,
            ["aud"] = audience,
            ["sub"] = subject,
            ["tenant"] = tenant,
            ["exp"] = expires,
        };

    private static string SignJwt(RSA key, string kid, JsonObject claims)
    {
        var header = new JsonObject
        {
            ["alg"] = "RS256",
            ["kid"] = kid,
            ["typ"] = "JWT",
        };
        var encodedHeader = Base64Url(Encoding.UTF8.GetBytes(header.ToJsonString()));
        var encodedClaims = Base64Url(Encoding.UTF8.GetBytes(claims.ToJsonString()));
        var signingInput = encodedHeader + "." + encodedClaims;
        var signature = key.SignData(
            Encoding.ASCII.GetBytes(signingInput),
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1);
        return signingInput + "." + Base64Url(signature);
    }

    private static string Jwks(RSA key, string kid)
    {
        var parameters = key.ExportParameters(false);
        return new JsonObject
        {
            ["keys"] = new JsonArray
            {
                new JsonObject
                {
                    ["kid"] = kid,
                    ["kty"] = "RSA",
                    ["use"] = "sig",
                    ["alg"] = "RS256",
                    ["n"] = Base64Url(parameters.Modulus!),
                    ["e"] = Base64Url(parameters.Exponent!),
                },
            },
        }.ToJsonString();
    }

    private static string Base64Url(byte[] value)
        => Convert.ToBase64String(value)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

    private sealed class LoopbackProvider : IDisposable
    {
        private readonly TcpListener _listener;
        private readonly CancellationTokenSource _stopped = new();
        private readonly Task _server;
        private readonly string _jwks;

        public LoopbackProvider(string jwks)
        {
            _jwks = jwks;
            _listener = new TcpListener(IPAddress.Loopback, 0);
            _listener.Start();
            var port = ((IPEndPoint)_listener.LocalEndpoint).Port;
            Issuer = $"http://127.0.0.1:{port}";
            _server = Task.Run(RunAsync);
        }

        public string Issuer { get; }

        public void Dispose()
        {
            _stopped.Cancel();
            _listener.Stop();
            try
            {
                _server.Wait(TimeSpan.FromSeconds(2));
            }
            catch (Exception)
            {
            }
            _stopped.Dispose();
        }

        private async Task RunAsync()
        {
            while (!_stopped.IsCancellationRequested)
            {
                TcpClient client;
                try
                {
                    client = await _listener.AcceptTcpClientAsync(_stopped.Token);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (ObjectDisposedException)
                {
                    return;
                }
                _ = Task.Run(() => Handle(client));
            }
        }

        private void Handle(TcpClient client)
        {
            using (client)
            using (var stream = client.GetStream())
            {
                try
                {
                    var headers = ReadHeaders(stream);
                    var requestLine = headers
                        .Split("\r\n", StringSplitOptions.RemoveEmptyEntries)
                        .FirstOrDefault() ?? "";
                    var path = requestLine.Split(' ').ElementAtOrDefault(1) ?? "";
                    string? body = path switch
                    {
                        "/.well-known/openid-configuration" => new JsonObject
                        {
                            ["issuer"] = Issuer,
                            ["jwks_uri"] = Issuer + "/jwks",
                        }.ToJsonString(),
                        "/jwks" => _jwks,
                        _ => null,
                    };
                    if (body is null)
                    {
                        WriteResponse(stream, 404, "{}");
                        return;
                    }
                    WriteResponse(stream, 200, body);
                }
                catch (Exception)
                {
                }
            }
        }

        private static string ReadHeaders(NetworkStream stream)
        {
            var buffer = new List<byte>();
            var single = new byte[1];
            while (buffer.Count < 65536)
            {
                var read = stream.Read(single, 0, 1);
                if (read == 0)
                {
                    break;
                }
                buffer.Add(single[0]);
                if (buffer.Count >= 4
                    && buffer[buffer.Count - 4] == (byte)'\r'
                    && buffer[buffer.Count - 3] == (byte)'\n'
                    && buffer[buffer.Count - 2] == (byte)'\r'
                    && buffer[buffer.Count - 1] == (byte)'\n')
                {
                    break;
                }
            }
            return Encoding.ASCII.GetString(buffer.ToArray());
        }

        private static void WriteResponse(
            NetworkStream stream,
            int status,
            string body)
        {
            var encoded = Encoding.UTF8.GetBytes(body);
            var reason = status == 200 ? "OK" : "Not Found";
            var header = Encoding.ASCII.GetBytes(
                $"HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\n" +
                $"Content-Length: {encoded.Length}\r\nConnection: close\r\n\r\n");
            stream.Write(header);
            stream.Write(encoded);
        }
    }
}
