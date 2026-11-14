void main() {
  final chunks = ['status: ', 'green'];
  final received = <String>[];
  final output = accumulate(chunks, received.add);
  if (output != 'status: green' ||
      received.join() != output ||
      received.length != chunks.length) {
    throw StateError('deltas did not reconstruct the output');
  }
  print('Dart streaming example passed');
}

String accumulate(List<String> chunks, void Function(String) onDelta) {
  final buffer = StringBuffer();
  for (final chunk in chunks) {
    buffer.write(chunk);
    onDelta(chunk);
  }
  return buffer.toString();
}
