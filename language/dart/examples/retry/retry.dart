void main() {
  final recovered = runRetry(2);
  if (recovered.$1 != 'status: green' || recovered.$2 != 3) {
    throw StateError('transient retry failed');
  }
  final exhausted = runRetry(3);
  if (exhausted.$1 != null || exhausted.$2 != 3) {
    throw StateError('exhausted retry failed');
  }
  print('Dart retry example passed');
}

(String?, int) runRetry(int failures) {
  for (var attempt = 1; attempt <= 3; attempt++) {
    if (attempt > failures) return ('status: green', attempt);
  }
  return (null, 3);
}
