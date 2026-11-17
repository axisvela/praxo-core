import '../../lib/praxo_core.dart';

class DemoState {
  final Map<String, int> effects = {};
  int childCalls = 0;
}

class DemoModel implements Model {
  DemoModel(this.steps, this.finalContent);

  final List<Response> steps;
  final String finalContent;

  @override
  Response generate(Request request) {
    if (steps.isNotEmpty) return steps.removeAt(0);
    return Response(message: Message.assistant(finalContent));
  }
}

Decision parentPolicy(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind == 'tool.invoke' && action.toolName == 'delegate') {
    return const Decision(allowed: true);
  }
  return const Decision(reason: 'parent may only delegate');
}

Decision childPolicy(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind == 'tool.invoke' && action.toolName == 'record') {
    return const Decision(allowed: true);
  }
  return const Decision(reason: 'child may only record');
}

ToolCall recordCall(String id, String target) => ToolCall(
      id: id,
      name: 'record',
      arguments: {'target': target},
    );

Future<void> main() async {
  final state = DemoState();
  final record = FuncTool('record', 'Record a target in an in-memory counter',
      (Map<String, dynamic> arguments) {
    final target = arguments['target']?.toString() ?? '';
    state.effects[target] = (state.effects[target] ?? 0) + 1;
    return 'recorded:$target';
  });

  final childModel = DemoModel([
    Response(
      message: Message.assistant('', [recordCall('child-record', 'child')]),
    ),
  ], 'child done');
  final delegate = FuncTool('delegate',
      'Run a child agent with a narrowed record scope',
      (Map<String, dynamic> arguments) {
    final result = Agent(AgentOptions(
      childModel,
      tools: Registry()..register(record),
      maxSteps: 3,
      allowedTools: const ['record'],
      policy: childPolicy,
      requirePolicy: true,
      requireToolScope: true,
    )).run(const Session(id: 'demo-child'), 'record child');
    return result.output;
  });

  final parentModel = DemoModel([
    Response(
      message: Message.assistant('', [
        ToolCall(
          id: 'parent-delegate',
          name: 'delegate',
          arguments: const {'task': 'record child'},
        ),
      ]),
    ),
  ], 'parent done');
  final registry = Registry()
    ..register(record)
    ..register(delegate);
  final result = Agent(AgentOptions(
    parentModel,
    tools: registry,
    allowedTools: const ['delegate'],
    policy: parentPolicy,
    requirePolicy: true,
    requireToolScope: true,
  )).run(const Session(id: 'demo-parent'), 'delegate');
  print('delegation: child recorded; parent scope enforced');

  final directModel = DemoModel([
    Response(
      message: Message.assistant('', [recordCall('direct-record', 'child')]),
    ),
  ], 'parent done');
  var denied = false;
  try {
    Agent(AgentOptions(
      directModel,
      tools: registry,
      allowedTools: const ['delegate'],
      policy: parentPolicy,
      requirePolicy: true,
      requireToolScope: true,
    )).run(const Session(id: 'demo-direct'), 'record directly');
  } on PraxoError {
    denied = true;
  }
  print('deny: parent record blocked; child effect unchanged');
  if (result.output != 'parent done' ||
      (state.effects['child'] ?? 0) != 1 ||
      !denied) {
    throw StateError('delegation example failed');
  }
}
