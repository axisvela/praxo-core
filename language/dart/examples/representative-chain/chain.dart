import 'dart:async';
import 'dart:convert';

import '../../lib/praxo_core.dart';

class ChainState {
  final Map<String, int> effects = {};
  final List<String> otel = [];
  final List<String> harmovela = [];
  int childCalls = 0;
}

class RecordServer {
  RecordServer(this.effects);

  final Map<String, int> effects;

  Map<String, dynamic> handle(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': '2024-11-05',
          'serverInfo': {'name': 'fake-mcp'},
        };
      case 'tools/list':
        return {
          'tools': [
            {
              'name': 'record',
              'description': 'Record a target',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'target': {'type': 'string'},
                },
                'required': ['target'],
              },
            },
          ],
        };
      case 'tools/call':
        final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
        final target = arguments['target']?.toString() ?? '';
        effects[target] = (effects[target] ?? 0) + 1;
        return {
          'content': [
            {'type': 'text', 'text': 'recorded:$target'},
          ],
        };
      default:
        return {};
    }
  }
}

class SyncTransport implements McpTransport {
  SyncTransport(this.server);

  final RecordServer server;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  ) async =>
      server.handle(method, params);

  @override
  void notify(String method, Map<String, dynamic> params) {}

  @override
  Future<void> close() async {}
}

class ChainModel implements Model {
  ChainModel(this.steps, this.finalContent, {this.onGenerate});

  final List<Response> steps;
  final String finalContent;
  final void Function()? onGenerate;
  int calls = 0;

  @override
  Response generate(Request request) {
    calls += 1;
    onGenerate?.call();
    if (steps.isNotEmpty) return steps.removeAt(0);
    return Response(message: Message.assistant(finalContent));
  }
}

Decision parentPolicy(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(reason: 'unsupported action');
  }
  if (action.toolName == 'record') {
    final target = action.arguments?['target']?.toString() ?? '';
    if (target == 'blocked') return const Decision(reason: 'blocked target');
    return const Decision(allowed: true);
  }
  if (action.toolName == 'delegate') return const Decision(allowed: true);
  return const Decision(reason: 'parent tool is not allowed');
}

Decision childPolicy(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind == 'tool.invoke' && action.toolName == 'record') {
    return const Decision(allowed: true);
  }
  return const Decision(reason: 'child may only record');
}

Decision composedPolicy(Action action) {
  final parent = parentPolicy(action);
  if (!parent.allowed) return parent;
  return childPolicy(action);
}

ToolCall recordCall(String id, String target) => ToolCall(
      id: id,
      name: 'record',
      arguments: {'target': target},
    );

Response toolResponse(ToolCall call) =>
    Response(message: Message.assistant('', [call]));

Future<void> main() async {
  final state = ChainState();
  final server = RecordServer(state.effects);
  final client = McpClient(transport: SyncTransport(server));
  await client.start();
  final tools = await client.listTools();
  if (tools.length != 1) throw StateError('unexpected MCP tools');

  final record = FuncTool('record', 'Record a target through the MCP seam',
      (Map<String, dynamic> arguments) {
    final target = arguments['target']?.toString() ?? '';
    return server.handle('tools/call', {
      'name': 'record',
      'arguments': {'target': target},
    });
  });

  final otel = OtelSink(
    endpoint: 'http://otel.local/v1/traces',
    transport: (method, url, body, headers) {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      for (final resource in (payload['resourceSpans'] as List? ?? const [])) {
        for (final scope in (resource['scopeSpans'] as List? ?? const [])) {
          for (final span in (scope['spans'] as List? ?? const [])) {
            state.otel.add(span['name']?.toString() ?? '');
          }
        }
      }
      return const OtelResponse(200, '');
    },
  );
  final harmovela = HarmovelaSink(
    baseUrl: 'http://harmovela.local',
    transport: (baseUrl, path, body, headers) {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      state.harmovela.add(payload['type']?.toString() ?? '');
      return const HarmovelaResponse(202, '');
    },
  );
  final events = MultiSink([otel, harmovela]);

  final delegate = FuncTool('delegate',
      'Run a governed child agent with a narrowed record scope',
      (Map<String, dynamic> arguments) {
    final childModel = ChainModel([
      toolResponse(recordCall('child-record', 'child')),
    ], 'DONE', onGenerate: () => state.childCalls += 1);
    final childRegistry = Registry()..register(record);
    final childOptions = AgentOptions(
      childModel,
      tools: childRegistry,
      maxSteps: 3,
      allowedTools: const ['record'],
      policy: composedPolicy,
      requirePolicy: true,
      requireToolScope: true,
      events: events,
    );
    final result = Agent(childOptions)
        .run(const Session(id: 'chain-child'), 'record child');
    return {
      'output': result.output,
      'effects': state.effects['child'] ?? 0,
    };
  });

  final parentModel = ChainModel([
    toolResponse(recordCall('parent-record', 'parent')),
    toolResponse(ToolCall(
      id: 'parent-delegate',
      name: 'delegate',
      arguments: const {'task': 'record child'},
    )),
  ], 'DONE');
  final parentRegistry = Registry()
    ..register(record)
    ..register(delegate);
  final parentOptions = AgentOptions(
    parentModel,
    tools: parentRegistry,
    maxSteps: 4,
    allowedTools: const ['record', 'delegate'],
    policy: parentPolicy,
    requirePolicy: true,
    requireToolScope: true,
    events: events,
  );
  final parent = Agent(parentOptions)
      .run(const Session(id: 'chain-parent'), 'record parent, then delegate');

  final deniedModel = ChainModel([
    toolResponse(recordCall('denied-record', 'edit-me')),
  ], 'DONE');
  final deniedOptions = AgentOptions(
    deniedModel,
    tools: Registry()..register(record),
    maxSteps: 2,
    allowedTools: const ['record'],
    policy: parentPolicy,
    requirePolicy: true,
    requireToolScope: true,
    events: events,
    interruptOn: const ['record'],
    onInterruptDecision: (interrupt) => InterruptDecision(
      action: interruptEdit,
      arguments: const {'target': 'blocked'},
    ),
  );
  String deniedError = '';
  try {
    Agent(deniedOptions)
        .run(const Session(id: 'chain-denied'), 'attempt a denied edit');
  } on PraxoError catch (error) {
    deniedError = error.code;
  }

  await client.close();
  print('output: ${parent.output}');
  print('effects: parent=${state.effects['parent'] ?? 0} '
      'child=${state.effects['child'] ?? 0}');
  print('child calls: ${state.childCalls}');
  print('otel spans: ${state.otel.length}');
  print('harmovela events: ${state.harmovela.length}');
  print('denied effects: ${state.effects['blocked'] ?? 0}');
  if (parent.output != 'DONE' ||
      (state.effects['parent'] ?? 0) != 1 ||
      (state.effects['child'] ?? 0) != 1 ||
      state.childCalls != 2 ||
      state.otel.length < 3 ||
      state.harmovela.length < 3 ||
      (state.effects['blocked'] ?? 0) != 0 ||
      deniedError.isEmpty) {
    throw StateError('representative chain failed');
  }
}
