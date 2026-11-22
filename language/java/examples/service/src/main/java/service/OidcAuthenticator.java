package service;

import com.axisvela.praxo.util.Json;

import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class OidcAuthenticator implements RequestAuthenticator {
    private static final long CACHE_TTL_MILLIS = Duration.ofMinutes(5).toMillis();

    private final HttpClient client;
    private final String issuer;
    private final String audience;
    private final String jwksUrl;
    private final String discoveryUrl;
    private final String tenantClaim;

    private Map<String, JwkKey> keys;
    private long keysFetched;
    private Map<String, Object> metadata;
    private long metadataFetched;

    OidcAuthenticator(
            HttpClient client,
            String issuer,
            String audience,
            String jwksUrl,
            String discoveryUrl,
            String tenantClaim) {
        if (issuer == null || issuer.isBlank()) {
            throw new IllegalArgumentException("issuer is required");
        }
        if (audience == null || audience.isBlank()) {
            throw new IllegalArgumentException("audience is required");
        }
        this.client = client;
        this.issuer = trimSlash(issuer);
        this.audience = audience;
        this.jwksUrl = jwksUrl == null ? "" : jwksUrl;
        this.discoveryUrl = discoveryUrl == null ? "" : discoveryUrl;
        this.tenantClaim =
                tenantClaim == null || tenantClaim.isBlank() ? "tenant" : tenantClaim;
    }

    @Override
    public AuthenticatedPrincipal authenticate(
            String principal, String authorization, Instant now) {
        if (authorization == null
                || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return null;
        }
        String token = authorization.substring(7).trim();
        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            return null;
        }
        try {
            Map<String, Object> header = Json.object(
                    new String(base64Url(parts[0]), StandardCharsets.UTF_8));
            String algorithm = stringClaim(header, "alg");
            String kid = stringClaim(header, "kid");
            if (algorithm == null || kid == null || kid.isEmpty()) {
                return null;
            }
            String javaAlgorithm = switch (algorithm) {
                case "RS256" -> "SHA256withRSA";
                case "RS384" -> "SHA384withRSA";
                case "RS512" -> "SHA512withRSA";
                default -> null;
            };
            if (javaAlgorithm == null) {
                return null;
            }
            Map<String, Object> claims = Json.object(
                    new String(base64Url(parts[1]), StandardCharsets.UTF_8));
            String tokenIssuer = stringClaim(claims, "iss");
            if (tokenIssuer == null || !trimSlash(tokenIssuer).equals(issuer)) {
                return null;
            }
            if (!audienceMatches(claims.get("aud"), audience)) {
                return null;
            }
            long expires = longClaim(claims, "exp");
            if (expires <= 0 || expires <= now.getEpochSecond()) {
                return null;
            }
            Object notBeforeValue = claims.get("nbf");
            if (notBeforeValue != null && longClaim(claims, "nbf") > now.getEpochSecond()) {
                return null;
            }
            String subject = stringClaim(claims, "sub");
            String tenant = stringClaim(claims, tenantClaim);
            if (subject == null || subject.isEmpty()
                    || tenant == null || tenant.isEmpty()) {
                return null;
            }
            JwkKey key = findKey(kid, algorithm, false);
            if (key == null) {
                key = findKey(kid, algorithm, true);
            }
            if (key == null || !verify(key, javaAlgorithm, parts[0] + "." + parts[1],
                    base64Url(parts[2]))) {
                return null;
            }
            return new AuthenticatedPrincipal(subject, tenant, expires);
        } catch (Exception error) {
            return null;
        }
    }

    private synchronized JwkKey findKey(String kid, String algorithm, boolean refresh)
            throws Exception {
        if (keys == null || refresh || System.currentTimeMillis() - keysFetched > CACHE_TTL_MILLIS) {
            String url = jwksUrl;
            if (url.isEmpty()) {
                url = metadata().get("jwks_uri") instanceof String value ? value : "";
            }
            if (url.isEmpty()) {
                throw new IllegalStateException("identity provider JWKS is not configured");
            }
            keys = fetchKeys(url);
            keysFetched = System.currentTimeMillis();
        }
        JwkKey key = keys.get(kid);
        if (key == null || !key.kind().equals("RSA")
                || (!key.use().isEmpty() && !key.use().equals("sig"))
                || (!key.algorithm().isEmpty() && !key.algorithm().equals(algorithm))) {
            return null;
        }
        return key;
    }

    private synchronized Map<String, Object> metadata() throws Exception {
        if (metadata != null
                && System.currentTimeMillis() - metadataFetched <= CACHE_TTL_MILLIS) {
            return metadata;
        }
        String url = discoveryUrl.isEmpty()
                ? issuer + "/.well-known/openid-configuration"
                : discoveryUrl;
        Map<String, Object> body = fetchObject(url);
        String providerIssuer = stringClaim(body, "issuer");
        if (providerIssuer == null
                || !trimSlash(providerIssuer).equals(issuer)) {
            throw new IllegalStateException("invalid provider issuer");
        }
        metadata = body;
        metadataFetched = System.currentTimeMillis();
        return metadata;
    }

    private Map<String, JwkKey> fetchKeys(String url) throws Exception {
        Map<String, Object> body = fetchObject(url);
        List<Object> items = Json.asArray(body.get("keys"));
        Map<String, JwkKey> result = new LinkedHashMap<>();
        for (Object item : items) {
            if (!(item instanceof Map<?, ?> raw)) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> key = (Map<String, Object>) raw;
            String kid = stringClaim(key, "kid");
            String kind = stringClaim(key, "kty");
            String modulus = stringClaim(key, "n");
            String exponent = stringClaim(key, "e");
            if (kid == null || kid.isEmpty()
                    || kind == null || kind.isEmpty()
                    || modulus == null || modulus.isEmpty()
                    || exponent == null || exponent.isEmpty()) {
                continue;
            }
            result.put(kid, new JwkKey(
                    kid,
                    kind,
                    stringOrEmpty(key, "use"),
                    stringOrEmpty(key, "alg"),
                    modulus,
                    exponent));
        }
        return result;
    }

    private Map<String, Object> fetchObject(String url) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(2))
                .GET()
                .build();
        HttpResponse<String> response = client.send(
                request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException("identity provider unavailable");
        }
        return Json.object(response.body());
    }

    private static boolean verify(
            JwkKey key, String algorithm, String signingInput, byte[] signature)
            throws Exception {
        byte[] modulus = base64Url(key.modulus());
        byte[] exponent = base64Url(key.exponent());
        if (modulus.length == 0 || exponent.length == 0 || exponent.length > 8) {
            return false;
        }
        PublicKey publicKey = KeyFactory.getInstance("RSA").generatePublic(
                new RSAPublicKeySpec(
                        new BigInteger(1, modulus),
                        new BigInteger(1, exponent)));
        Signature verifier = Signature.getInstance(algorithm);
        verifier.initVerify(publicKey);
        verifier.update(signingInput.getBytes(StandardCharsets.US_ASCII));
        return verifier.verify(signature);
    }

    private static boolean audienceMatches(Object value, String expected) {
        if (value instanceof String text) {
            return text.equals(expected);
        }
        if (value instanceof List<?> values) {
            for (Object item : values) {
                if (item instanceof String text && text.equals(expected)) {
                    return true;
                }
            }
        }
        return false;
    }

    private static String stringClaim(Map<String, Object> values, String key) {
        Object value = values.get(key);
        return value instanceof String text ? text : null;
    }

    private static String stringOrEmpty(Map<String, Object> values, String key) {
        String value = stringClaim(values, key);
        return value == null ? "" : value;
    }

    private static long longClaim(Map<String, Object> values, String key) {
        Object value = values.get(key);
        if (value instanceof Number number) {
            return number.longValue();
        }
        throw new IllegalArgumentException("expected integer");
    }

    private static byte[] base64Url(String value) {
        String text = value.replace('-', '+').replace('_', '/');
        int remainder = text.length() % 4;
        if (remainder == 2) {
            text += "==";
        } else if (remainder == 3) {
            text += "=";
        }
        return Base64.getDecoder().decode(text);
    }

    private static String trimSlash(String value) {
        int end = value.length();
        while (end > 0 && value.charAt(end - 1) == '/') {
            end--;
        }
        return value.substring(0, end);
    }

    private record JwkKey(
            String kid,
            String kind,
            String use,
            String algorithm,
            String modulus,
            String exponent) {
    }
}
