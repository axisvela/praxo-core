import 'dart:io';

import '../../lib/praxo_core.dart';

class FixtureModel implements Model {
  @override
  Response generate(Request request) {
    final last = request.messages.last;
    if (last.role == roleTool) {
      return Response(message: Message.assistant('done'));
    }
    return Response(
      message: Message.assistant('', [
        const ToolCall(
          id: 'write-note-1',
          name: 'write_note',
          arguments: {'text': 'hello', 'visibility': 'public'},
        ),
      ]),
    );
  }
}

class WriteNoteTool implements Tool {
  @override
  final String name = 'write_note';
  @override
  final String description =
      'Write a short note with the requested visibility.';

  final List<String> notes = [];

  @override
  dynamic invoke(Map<String, dynamic> arguments) {
    notes.add(arguments['text'] as String);
    return 'written';
  }
}

Decision allowPublic(Action action) {
  if (action.kind == 'model.generate') {
    return const Decision(allowed: true);
  }
  if (action.kind == 'tool.invoke') {
    return Decision(
      allowed: action.toolName == 'write_note' &&
          action.arguments?['visibility'] == 'public',
      reason: 'only public notes are permitted',
    );
  }
  return const Decision(allowed: false, reason: 'unsupported action');
}

(Agent, WriteNoteTool) buildAgent(InterruptDecision decision) {
  final tool = WriteNoteTool();
  final registry = Registry()..register(tool);
  final agent = Agent(AgentOptions(
    FixtureModel(),
    tools: registry,
    maxSteps: 3,
    allowedTools: const ['write_note'],
    policy: allowPublic,
    interruptOn: const ['write_note'],
    onInterruptDecision: (_) => decision,
  ));
  return (agent, tool);
}

void run(StringSink output) {
  final (approveAgent, approveTool) =
      buildAgent(const InterruptDecision(action: interruptApprove));
  final approved =
      approveAgent.run(const Session(id: 'hitl-approve'), 'Write a note.');
  if (approved.output != 'done' || approveTool.notes.length != 1) {
    throw StateError('approve scenario failed: output=${approved.output} '
        'effects=${approveTool.notes.length}');
  }
  output.writeln('approve: written; effects=1');

  final (editAgent, editTool) = buildAgent(const InterruptDecision(
    action: interruptEdit,
    arguments: {'text': 'hello', 'visibility': 'private'},
  ));
  var denied = false;
  try {
    editAgent.run(const Session(id: 'hitl-edit'), 'Write a note.');
  } on PraxoError catch (error) {
    denied = error.code == 'AGENT_POLICY_DENIED';
  }
  if (!denied || editTool.notes.isNotEmpty) {
    throw StateError('edit scenario failed: effects=${editTool.notes.length}');
  }
  output.writeln('edit: policy rejected; effects=0');
}

void main() {
  run(stdout);
}
