package service;

import com.axisvela.praxo.util.Json;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

record AuthenticatedPrincipal(String subject, String tenant, long expires) {
}

interface RequestAuthenticator {
    AuthenticatedPrincipal authenticate(
            String principal, String authorization, Instant now);
}

final class ContextAuthenticator implements RequestAuthenticator {
    private final String tenant;

    ContextAuthenticator(String tenant) {
        this.tenant = tenant;
    }

    @Override
    public AuthenticatedPrincipal authenticate(
            String principal, String authorization, Instant now) {
        if (principal == null || principal.isEmpty()) {
            return null;
        }
        return new AuthenticatedPrincipal(principal, tenant, Long.MAX_VALUE);
    }
}

final class IntrospectionAuthenticator implements RequestAuthenticator {
    private final HttpClient client;
    private final URI endpoint;
    private final String clientId;
    private final String clientSecret;
    private final String tenantClaim;

    IntrospectionAuthenticator(
            HttpClient client,
            URI endpoint,
            String clientId,
            String clientSecret,
            String tenantClaim) {
        this.client = client;
        this.endpoint = endpoint;
        this.clientId = clientId == null ? "" : clientId;
        this.clientSecret = clientSecret == null ? "" : clientSecret;
        this.tenantClaim =
                tenantClaim == null || tenantClaim.isEmpty() ? "tenant" : tenantClaim;
    }

    @Override
    public AuthenticatedPrincipal authenticate(
            String principal, String authorization, Instant now) {
        if (authorization == null
                || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return null;
        }
        String token = authorization.substring(7).trim();
        if (token.isEmpty()) {
            return null;
        }
        try {
            String form = "token=" + encode(token)
                    + "&client_id=" + encode(clientId)
                    + "&client_secret=" + encode(clientSecret);
            HttpRequest.Builder builder = HttpRequest.newBuilder(endpoint)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .timeout(Duration.ofSeconds(2))
                    .POST(HttpRequest.BodyPublishers.ofString(form));
            if (!clientId.isEmpty()) {
                String raw = clientId + ":" + clientSecret;
                builder.header("Authorization", "Basic " + Base64.getEncoder()
                        .encodeToString(raw.getBytes(StandardCharsets.UTF_8)));
            }
            HttpResponse<String> response = client.send(
                    builder.build(), HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                return null;
            }
            Map<String, Object> body = Json.object(response.body());
            if (!Boolean.TRUE.equals(body.get("active"))) {
                return null;
            }
            Object subjectValue = body.get("sub");
            Object tenantValue = body.get(tenantClaim);
            Object expiresValue = body.get("exp");
            if (!(subjectValue instanceof String subject) || subject.isEmpty()
                    || !(tenantValue instanceof String tenant) || tenant.isEmpty()
                    || !(expiresValue instanceof Number number)) {
                return null;
            }
            long expires = number.longValue();
            if (expires <= now.getEpochSecond()) {
                return null;
            }
            return new AuthenticatedPrincipal(subject, tenant, expires);
        } catch (Exception error) {
            return null;
        }
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}

final class RevocationClient {
    private RevocationClient() {
    }

    static void revoke(
            String token,
            HttpClient client,
            URI endpoint,
            String clientId,
            String clientSecret) throws Exception {
        if (token == null || token.isEmpty()) {
            throw new IllegalArgumentException("revocation token is required");
        }
        String form = "token=" + encode(token)
                + "&token_type_hint=access_token"
                + "&client_id=" + encode(clientId)
                + "&client_secret=" + encode(clientSecret);
        HttpRequest.Builder builder = HttpRequest.newBuilder(endpoint)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .timeout(Duration.ofSeconds(2))
                .POST(HttpRequest.BodyPublishers.ofString(form));
        if (clientId != null && !clientId.isEmpty()) {
            String raw = clientId + ":" + clientSecret;
            builder.header("Authorization", "Basic " + Base64.getEncoder()
                    .encodeToString(raw.getBytes(StandardCharsets.UTF_8)));
        }
        HttpResponse<String> response =
                client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException("token revocation failed");
        }
    }

    private static String encode(String value) {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }
}
