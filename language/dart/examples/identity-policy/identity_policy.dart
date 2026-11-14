void main() {
  final operator = {'tenant': 'acme', 'role': 'operator', 'active': true};
  if (!authorize(operator, 'record', 'acme')) throw StateError('operator denied');
  if (authorize({...operator, 'role': 'viewer'}, 'record', 'acme')) {
    throw StateError('viewer allowed');
  }
  if (authorize(operator, 'record', 'other')) throw StateError('tenant mismatch allowed');
  if (authorize(null, 'record', 'acme')) throw StateError('missing principal allowed');
  print('Dart identity policy example passed');
}

bool authorize(Map<String, dynamic>? principal, String tool, String tenant) {
  if (principal == null) return false;
  if (principal['active'] != true) return false;
  if (principal['role'] != 'operator') return false;
  if (principal['tenant'] != tenant) return false;
  return tool == 'record';
}
