void main() {
  final primary = runFallback(primaryFails: false, fallbackFails: false);
  if (primary != 'primary') throw StateError('primary path failed');
  final fallback = runFallback(primaryFails: true, fallbackFails: false);
  if (fallback != 'fallback') throw StateError('fallback path failed');
  final failed = runFallback(primaryFails: true, fallbackFails: true);
  if (failed != 'MODEL_UNAVAILABLE') throw StateError('both-failure path failed');
  print('Dart provider fallback example passed');
}

String runFallback({required bool primaryFails, required bool fallbackFails}) {
  if (!primaryFails) return 'primary';
  if (!fallbackFails) return 'fallback';
  return 'MODEL_UNAVAILABLE';
}
