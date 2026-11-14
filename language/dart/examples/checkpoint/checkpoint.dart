import '../../lib/praxo_core.dart';

void main() {
  final allow = CheckpointAllowlist();
  allow.register('order');
  final encoded = allow.marshal('order', {'value': 'x'});
  final decoded = allow.unmarshal(encoded);
  if (!Json.equals(decoded, {'value': 'x'})) {
    throw StateError('checkpoint payload did not round trip');
  }
  print('Dart checkpoint example passed');
}
