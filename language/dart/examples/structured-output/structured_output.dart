import '../../lib/praxo_core.dart';

void main() {
  final schema = {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
    },
  };
  if (validate(schema, {'name': 'ok'}).isNotEmpty) {
    throw StateError('valid output was rejected');
  }
  if (validate(schema, {}).isEmpty) {
    throw StateError('invalid output was accepted');
  }
  print('Dart structured output example passed');
}
