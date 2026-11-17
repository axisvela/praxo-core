import '../../lib/praxo_core.dart';

class GovState {
  final Map<String, int> effects = {};
  int budget = 0;
  int children = 0;
}

class RunConfig {
  RunConfig({
    required this.allowed,
    required this.policy,
    required this.tools,
    this.depth = 0,
    this.maxDepth = -1,
    this.maxChildren = -1,
    this.useBudget = false,
    this.useChildren = false,
    this.cancelled = false,
    this.editToBlocked = false,
  });

  final List<String> allowed;
  final Decision Function(Action) policy;
  final List<Tool> tools;
  final int depth;
  final int maxDepth;
  final int maxChildren;
  final bool useBudget;
  final bool useChildren;
  final bool cancelled;
  final bool editToBlocked;
}

class GovModel implements Model {
  GovModel(this.steps);

  final List<Response> steps;

  @override
  Response generate(Request request) {
    if (steps.isNotEmpty) return steps.removeAt(0);
    return Response(message: Message.assistant('done'));
  }
}

Decision allow() => const Decision(allowed: true);
Decision deny(String reason) => Decision(reason: reason);

String targetOf(Action action) =>
    action.arguments?['target']?.toString() ?? '';

Decision permissiveRecord(Action action) {
  if (action.kind == 'model.generate') return allow();
  if (action.kind == 'tool.invoke' && action.toolName == 'record') {
    return allow();
  }
  return deny('child may only record');
}

Decision parentDenyBlocked(Action action) {
  if (action.kind == 'model.generate') return allow();
  if (action.kind != 'tool.invoke' || action.toolName != 'record') {
    return deny('parent tool is not allowed');
  }
  if (targetOf(action) == 'blocked') return deny('blocked target');
  return allow();
}

Decision composedPolicy(Action action) {
  final parent = parentDenyBlocked(action);
  if (!parent.allowed) return parent;
  return permissiveRecord(action);
}

SubagentTask deniedTask(String status, String error) => SubagentTask(
      id: 'subagent',
      parentSessionId: 'governance-parent',
      agentId: 'governance-child',
      mode: 'isolated',
      status: status,
      output: '',
      error: error,
      createdAt: '',
      updatedAt: '',
    );

List<Tool> makeTools(GovState state) => [
      FuncTool('record', 'record', (Map<String, dynamic> arguments) {
        final target = arguments['target']?.toString() ?? '';
        state.effects[target] = (state.effects[target] ?? 0) + 1;
        return 'ok';
      }),
      FuncTool('write', 'write', (Map<String, dynamic> arguments) {
        final target = arguments['target']?.toString() ?? '';
        state.effects[target] = (state.effects[target] ?? 0) + 1;
        return 'ok';
      }),
    ];

GovModel modelFor(String tool, String target) => GovModel([
      Response(
        message: Message.assistant('', [
          ToolCall(
            id: 'call-1',
            name: tool,
            arguments: {'target': target},
          ),
        ]),
      ),
      Response(message: Message.assistant('done')),
    ]);

Future<SubagentTask> runChild(
    GovState state, GovModel model, RunConfig config) async {
  if (config.cancelled) return deniedTask('cancelled', 'CANCELLED');
  if (config.maxDepth >= 0 && config.depth > config.maxDepth) {
    return deniedTask('denied', 'DEPTH_LIMIT');
  }
  if (config.maxChildren >= 0 && state.children >= config.maxChildren) {
    return deniedTask('denied', 'CHILD_LIMIT');
  }
  if (config.useBudget && state.budget <= 0) {
    return deniedTask('denied', 'BUDGET_EXHAUSTED');
  }
  if (config.useChildren) state.children += 1;

  final registry = Registry();
  for (final tool in config.tools) {
    registry.register(tool);
  }
  final options = AgentOptions(
    model,
    tools: registry,
    maxSteps: 3,
    allowedTools: config.allowed,
    policy: config.policy,
    requirePolicy: true,
    requireToolScope: true,
  );
  if (config.editToBlocked) {
    options.interruptOn = const ['record'];
    options.onInterruptDecision = (interrupt) => InterruptDecision(
          action: interruptEdit,
          arguments: const {'target': 'blocked'},
        );
  }
  final manager = SubagentManager((request) async {
    final result =
        Agent(options).run(const Session(id: 'governance-child'), 'run child');
    return SubagentResult(
      taskId: 'child',
      agentId: 'child',
      output: result.output,
    );
  });
  final task = await manager.run(const SubagentRequest(
    parentSessionId: 'governance-parent',
    agentId: 'governance-child',
    prompt: 'run child',
  ));
  if (config.useBudget && task.status == 'completed') state.budget -= 1;
  return task;
}

Future<void> main() async {
  final scopeState = GovState();
  final scope = await runChild(scopeState, modelFor('write', 'escape'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(scopeState),
      ));
  if (scope.status != 'failed' || (scopeState.effects['escape'] ?? 0) != 0) {
    throw StateError('scope narrowing failed');
  }

  final policyState = GovState();
  final composed = await runChild(policyState, modelFor('record', 'blocked'),
      RunConfig(
        allowed: const ['record'],
        policy: composedPolicy,
        tools: makeTools(policyState),
      ));
  if (composed.status != 'failed' ||
      (policyState.effects['blocked'] ?? 0) != 0) {
    throw StateError('policy composition failed');
  }

  final budgetState = GovState()..budget = 1;
  final first = await runChild(budgetState, modelFor('record', 'sibling'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(budgetState),
        useBudget: true,
      ));
  final second = await runChild(budgetState, modelFor('record', 'sibling'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(budgetState),
        useBudget: true,
      ));
  if (first.status != 'completed' ||
      second.status != 'denied' ||
      second.error != 'BUDGET_EXHAUSTED' ||
      (budgetState.effects['sibling'] ?? 0) != 1) {
    throw StateError('sibling budget failed');
  }

  final limitState = GovState();
  final firstLimit = await runChild(limitState, modelFor('record', 'limit'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(limitState),
        maxChildren: 1,
        useChildren: true,
      ));
  final secondLimit = await runChild(limitState, modelFor('record', 'limit'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(limitState),
        maxChildren: 1,
        useChildren: true,
      ));
  final deep = await runChild(limitState, modelFor('record', 'limit'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(limitState),
        depth: 2,
        maxDepth: 1,
      ));
  if (firstLimit.status != 'completed' ||
      secondLimit.error != 'CHILD_LIMIT' ||
      deep.error != 'DEPTH_LIMIT' ||
      (limitState.effects['limit'] ?? 0) != 1) {
    throw StateError('limit checks failed');
  }

  final cancelState = GovState();
  final cancelled = await runChild(cancelState, modelFor('record', 'cancel'),
      RunConfig(
        allowed: const ['record'],
        policy: permissiveRecord,
        tools: makeTools(cancelState),
        cancelled: true,
      ));
  if (cancelled.status != 'cancelled' ||
      (cancelState.effects['cancel'] ?? 0) != 0) {
    throw StateError('cancellation failed');
  }

  final editState = GovState();
  final edited = await runChild(editState, modelFor('record', 'edit-me'),
      RunConfig(
        allowed: const ['record'],
        policy: parentDenyBlocked,
        tools: makeTools(editState),
        editToBlocked: true,
      ));
  if (edited.status != 'failed' ||
      (editState.effects['edit-me'] ?? 0) != 0 ||
      (editState.effects['blocked'] ?? 0) != 0) {
    throw StateError('final-argument reauthorization failed');
  }

  print('Dart advanced delegation governance: 6/6 passed');
}
