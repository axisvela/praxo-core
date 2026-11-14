void main() {
  final health = handle('GET', '/healthz', null, '');
  if (health.$1 != 200) throw StateError('health failed');
  final unauthorized = handle('POST', '/run', null, '{"prompt":"hi"}');
  if (unauthorized.$1 != 401) throw StateError('missing principal accepted');
  final ok = handle('POST', '/run', 'user-1', '{"prompt":"hi"}');
  if (ok.$1 != 200 || !ok.$2.contains('hello from the service')) {
    throw StateError('run failed');
  }
  print('Dart service example passed');
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
