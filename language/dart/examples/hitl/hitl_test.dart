import 'hitl.dart';

void main() {
  final output = StringBuffer();
  run(output);
  const expected = 'approve: written; effects=1\n'
      'edit: policy rejected; effects=0\n';
  if (output.toString() != expected) {
    throw StateError('unexpected hitl output: ${output.toString()}');
  }
  print('dart hitl example passed');
}
