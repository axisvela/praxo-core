import 'dart:io';

import '../../lib/praxo_core.dart';

class FixtureModel implements Model {
  FixtureModel(this.target);

  final String target;

  @override
  Response generate(Request request) {
    final last = request.messages.last;
    if (last.role == roleTool) {
      return Response(message: Message.assistant('recorded'));
    }
    return Response(
      message: Message.assistant('', [
        ToolCall(
          id: 'record-1',
          name: 'record',
          arguments: {'target': target},
        ),
      ]),
    );
  }
}

class RecordTool implements Tool {
  @override
  final String name = 'record';
  @override
  final String description = 'Record a target in an in-memory counter.';

  int calls = 0;

  @override
  dynamic invoke(Map<String, dynamic> arguments) {
    calls += 1;
    return 'recorded';
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') {
    return const Decision(allowed: true);
  }
  if (action.kind == 'tool.invoke') {
    final target = action.arguments?['target'];
    return Decision(
      allowed: action.toolName == 'record' && target == 'public',
      reason: 'only the public target is permitted',
    );
  }
  return const Decision(allowed: false, reason: 'unsupported action');
}

String runScenario(String target, List<int> effects) {
  final tool = RecordTool();
  final registry = Registry()..register(tool);
  final options = AgentOptions(
    FixtureModel(target),
    tools: registry,
    maxSteps: 3,
    allowedTools: const ['record'],
    policy: authorize,
  );
  try {
    final result = runAgent(
        options, Session(id: 'consumer-$target'), 'Record the requested target.');
    return result.output;
  } finally {
    effects[0] = tool.calls;
  }
}

void main() {
  final allowedEffects = [0];
  final output = runScenario('public', allowedEffects);
  if (output != 'recorded' || allowedEffects[0] != 1) {
    stderr.writeln(
        'allow verification failed: output=$output effects=${allowedEffects[0]}');
    exit(1);
  }
  print('allow: recorded; effects=1');

  final deniedEffects = [0];
  var denied = false;
  try {
    runScenario('private', deniedEffects);
  } on PraxoError catch (error) {
    denied = error.code == 'POLICY_ERROR';
  }
  if (!denied || deniedEffects[0] != 0) {
    stderr.writeln('deny verification failed: effects=${deniedEffects[0]}');
    exit(1);
  }
  print('deny: policy rejected; effects=0');
}
