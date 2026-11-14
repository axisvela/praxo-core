import '../../lib/praxo_core.dart';

class RecordingSink implements EventSink {
  final List<String> types = [];

  @override
  void emit(Event event) => types.add(event.type);
}

void main() {
  final all = RecordingSink();
  final tool = RecordingSink();
  final filter = FilterSink(tool, (event) => event.type == 'tool.call');
  final multi = MultiSink([all, filter]);
  for (final type in ['run.started', 'tool.call', 'run.completed']) {
    multi.emit(Event(type: type, sessionId: 's1'));
  }
  if (all.types.join(',') != 'run.started,tool.call,run.completed' ||
      tool.types.join(',') != 'tool.call') {
    throw StateError('unexpected event delivery');
  }
  print('Dart event sink example passed');
}
