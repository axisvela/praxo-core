import 'dart:convert';
import 'dart:io';

class AuthenticatedPrincipal {
  AuthenticatedPrincipal(this.subject, this.tenant, this.expires);

  final String subject;
  final String tenant;
  final int? expires;
}

class AuthError implements Exception {
  AuthError(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class IntrospectionTransport {
  Future<(int, String)> postForm(
    String url,
    Map<String, String> form,
    String? authorization,
  );
}

class HttpTransport implements IntrospectionTransport {
  @override
  Future<(int, String)> postForm(
    String url,
    Map<String, String> form,
    String? authorization,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      if (authorization != null) {
        request.headers.set(HttpHeaders.authorizationHeader, authorization);
      }
      request.write(Uri(queryParameters: form).query);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      return (response.statusCode, body);
    } on Exception {
      throw AuthError('identity provider unavailable');
    } finally {
      client.close(force: true);
    }
  }
}

class ContextAuthenticator {
  ContextAuthenticator(this.tenant);

  final String tenant;

  AuthenticatedPrincipal? authenticate(
    String? principal, {
    String? authorization,
    int? now,
  }) {
    if (principal == null || principal.isEmpty) return null;
    return AuthenticatedPrincipal(principal, tenant, null);
  }
}

class IntrospectionAuthenticator {
  IntrospectionAuthenticator({
    required this.transport,
    required this.endpoint,
    this.clientId = '',
    this.clientSecret = '',
    this.tenantClaim = 'tenant',
  });

  final IntrospectionTransport transport;
  final String endpoint;
  final String clientId;
  final String clientSecret;
  final String tenantClaim;

  Future<AuthenticatedPrincipal?> authenticate(
    String? authorization, {
    int? now,
  }) async {
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final token = authorization.substring('Bearer '.length).trim();
    if (token.isEmpty) return null;
    final current = now ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      final (status, body) = await transport.postForm(
        endpoint,
        {
          'token': token,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
        _basicAuth(),
      );
      if (status != 200) return null;
      final payload = jsonDecode(body);
      if (payload is! Map || payload['active'] != true) return null;
      final subject = payload['sub'];
      final tenant = payload[tenantClaim];
      final expires = payload['exp'];
      if (subject is! String || subject.isEmpty) return null;
      if (tenant is! String || tenant.isEmpty) return null;
      if (expires is! int || expires <= current) return null;
      return AuthenticatedPrincipal(subject, tenant, expires);
    } on AuthError {
      return null;
    } on FormatException {
      return null;
    }
  }

  String? _basicAuth() {
    if (clientId.isEmpty) return null;
    final raw = utf8.encode('$clientId:$clientSecret');
    return 'Basic ${base64Encode(raw)}';
  }
}

class RevocationClient {
  RevocationClient({
    required this.transport,
    required this.endpoint,
    this.clientId = '',
    this.clientSecret = '',
  });

  final IntrospectionTransport transport;
  final String endpoint;
  final String clientId;
  final String clientSecret;

  Future<void> revoke(String token) async {
    if (token.isEmpty) throw AuthError('revocation token is required');
    try {
      final (status, _) = await transport.postForm(
        endpoint,
        {
          'token': token,
          'token_type_hint': 'access_token',
          'client_id': clientId,
          'client_secret': clientSecret,
        },
        _basicAuth(),
      );
      if (status != 200) throw AuthError('token revocation failed');
    } on AuthError {
      rethrow;
    } on Exception {
      throw AuthError('token revocation failed');
    }
  }

  String? _basicAuth() {
    if (clientId.isEmpty) return null;
    final raw = utf8.encode('$clientId:$clientSecret');
    return 'Basic ${base64Encode(raw)}';
  }
}
