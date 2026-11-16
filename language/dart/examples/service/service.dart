import 'dart:convert';

import 'authentication.dart';

class ScriptedTransport implements IntrospectionTransport {
  ScriptedTransport(this.status, this.body);

  final int status;
  final String body;
  final List<Map<String, String>> forms = [];
  bool unavailable = false;

  @override
  Future<(int, String)> postForm(
    String url,
    Map<String, String> form,
    String? authorization,
  ) async {
    forms.add(form);
    if (unavailable) throw AuthError('identity provider unavailable');
    return (status, body);
  }
}

Future<void> main() async {
  await runAuthTests();
  final health = handle('GET', '/healthz', null, '');
  if (health.$1 != 200) throw StateError('health failed');
  final unauthorized = handle('POST', '/run', null, '{"prompt":"hi"}');
  if (unauthorized.$1 != 401) throw StateError('missing principal accepted');
  final ok = handle('POST', '/run', 'user-1', '{"prompt":"hi"}');
  if (ok.$1 != 200 || !ok.$2.contains('hello from the service')) {
    throw StateError('run failed');
  }
  print('Dart service example passed');
  print('Dart service auth tests passed');
}

Future<void> runAuthTests() async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final active = ScriptedTransport(
    200,
    jsonEncode({
      'active': true,
      'sub': 'user-1',
      'tenant': 'local',
      'exp': now + 60,
    }),
  );
  final authenticator = IntrospectionAuthenticator(
    transport: active,
    endpoint: 'https://id.example.com/introspect',
  );
  final principal = await authenticator.authenticate(
    'Bearer opaque-token',
    now: now,
  );
  if (principal == null ||
      principal.subject != 'user-1' ||
      principal.tenant != 'local') {
    throw StateError('active token was rejected');
  }

  final inactiveAuth = IntrospectionAuthenticator(
    transport: ScriptedTransport(200, jsonEncode({'active': false})),
    endpoint: 'https://id.example.com/introspect',
  );
  if (await inactiveAuth.authenticate('Bearer opaque-token', now: now) != null) {
    throw StateError('inactive token was accepted');
  }

  final missingAuth = IntrospectionAuthenticator(
    transport: ScriptedTransport(
      200,
      jsonEncode({'active': true, 'sub': 'user-1', 'tenant': 'local'}),
    ),
    endpoint: 'https://id.example.com/introspect',
  );
  if (await missingAuth.authenticate('Bearer opaque-token', now: now) != null) {
    throw StateError('missing expiration was accepted');
  }

  final unavailable = ScriptedTransport(200, '{}');
  unavailable.unavailable = true;
  final unavailableAuth = IntrospectionAuthenticator(
    transport: unavailable,
    endpoint: 'https://id.example.com/introspect',
  );
  if (await unavailableAuth.authenticate('Bearer opaque-token', now: now) !=
      null) {
    throw StateError('unavailable provider was accepted');
  }

  final revocation = RevocationClient(
    transport: active,
    endpoint: 'https://id.example.com/revoke',
  );
  await revocation.revoke('opaque-token');
  if (active.forms.last['token'] != 'opaque-token') {
    throw StateError('revocation did not post the token');
  }

  final failed = RevocationClient(
    transport: ScriptedTransport(503, '{}'),
    endpoint: 'https://id.example.com/revoke',
  );
  try {
    await failed.revoke('opaque-token');
    throw StateError('revocation failure was accepted');
  } on AuthError {
  }

  final context = ContextAuthenticator('local');
  if (context.authenticate('user-1')?.tenant != 'local') {
    throw StateError('context principal failed');
  }
}

(int, String) handle(String method, String path, String? principal, String body) {
  if (method == 'GET' && path == '/healthz') return (200, '{"status":"ok"}');
  if (method != 'POST' || path != '/run') return (404, '{"error":"not found"}');
  if (principal == null || principal.isEmpty) {
    return (401, '{"error":"missing X-Praxo-Principal"}');
  }
  if (!body.contains('"prompt"')) return (400, '{"error":"prompt is required"}');
  return (200, '{"output":"hello from the service"}');
}
