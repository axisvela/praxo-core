import '../../lib/praxo_core.dart';

class TurnModel implements Model {
  @override
  Response generate(Request request) =>
      Response(message: Message.assistant('turn ${request.messages.length}'));
}

void main() {
  final session = Session(id: 'session-1', messages: [
    Message.text(roleUser, 'first'),
    Message.text(roleAssistant, 'ack'),
  ]);
  final options = AgentOptions(TurnModel(), maxSteps: 2);
  final agent = Agent(options);

  var result = agent.run(session, 'second');
  if (result.output != 'turn 3') {
    throw StateError('unexpected second turn: ${result.output}');
  }
  session.messages.add(Message.text(roleUser, 'second'));
  session.messages.add(Message.assistant(result.output));

  final allow = CheckpointAllowlist()..register('session');
  final envelope = allow.marshal('session', {
    'messages': session.messages.map(messageWire).toList(),
  });
  final decoded = allow.unmarshal(envelope) as Map<String, dynamic>;
  final restored = (decoded['messages'] as List).cast<Map<String, dynamic>>();
  session.messages
    ..clear()
    ..addAll(restored.map((message) => Message(
          role: message['role'] as String,
          content: message['content'] as String?,
        )));

  result = agent.run(session, 'third');
  if (result.output != 'turn 5') {
    throw StateError('unexpected third turn: ${result.output}');
  }
  print('restored messages: ${session.messages.length}');
  print('output: ${result.output}');
}
