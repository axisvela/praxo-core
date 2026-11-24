import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const accountId = 'account-100';

class FixtureModel implements Model {
  FixtureModel(this.account);

  final String account;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'store-1', name: 'store_memory', arguments: {
            'account': account,
            'content': 'prefers morning meetings',
            'scope': 'work',
            'consent': true,
          }),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'recall-1', name: 'recall_memories', arguments: {
            'account': account,
            'scope': 'work',
          }),
        ]),
      );
    }
    if (results.length == 2) {
      final stored = jsonDecode(results[0].content ?? '{}') as Map<String, dynamic>;
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'forget-1', name: 'forget_memory', arguments: {
            'account': account,
            'memory_id': stored['memory_id'],
          }),
        ]),
      );
    }
    final stored = jsonDecode(results[0].content ?? '{}');
    final recalled = jsonDecode(results[1].content ?? '{}');
    final forgotten = jsonDecode(results[2].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'stored': stored,
        'recalled': recalled,
        'forgotten': forgotten,
        'unscoped_recalls': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['account'] == accountId;
  if (action.toolName == 'store_memory') {
    return Decision(
      allowed: inScope &&
          action.arguments?['scope'] == 'work' &&
          action.arguments?['consent'] == true,
      reason: 'only consent-scoped work memory is allowed',
    );
  }
  if (action.toolName == 'recall_memories') {
    return Decision(
      allowed: inScope && action.arguments?['scope'] == 'work',
      reason: 'only work-scoped recall is allowed',
    );
  }
  if (action.toolName == 'forget_memory') {
    return Decision(allowed: inScope, reason: 'only account-100 memory deletion is allowed');
  }
  return const Decision(allowed: false, reason: 'unsupported tool');
}

class Outcome {
  Outcome(this.report, this.stores, this.recalls, this.deletes, this.error);

  final Map<String, dynamic>? report;
  final int stores;
  final int recalls;
  final int deletes;
  final Object? error;
}

Outcome runMemory(String account, {bool simulateFailure = false}) {
  var stores = 0;
  var recalls = 0;
  var deletes = 0;
  final registry = Registry()
    ..register(FuncTool('store_memory', 'Store one consent-scoped synthetic memory; no real inbox.', (arguments) {
      if (arguments['account'] != accountId) throw Exception('account not found');
      stores += 1;
      if (simulateFailure) throw Exception('MEMORY_STORE_UNAVAILABLE');
      return {
        'memory_id': 'memory-100',
        'scope': arguments['scope'],
        'consent': arguments['consent'],
        'provenance': 'session_fixture',
        'stored': true,
      };
    }))
    ..register(FuncTool('recall_memories', 'Recall only scoped memories; no unrestricted recall.', (arguments) {
      recalls += 1;
      return {
        'scope': arguments['scope'],
        'memories': ['memory-100'],
        'unscoped': 0,
      };
    }))
    ..register(FuncTool('forget_memory', 'Delete a synthetic memory and confirm removal.', (arguments) {
      deletes += 1;
      return {
        'memory_id': arguments['memory_id'],
        'deleted': true,
        'remaining': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(account),
    tools: registry,
    maxSteps: 6,
    allowedTools: const ['store_memory', 'recall_memories', 'forget_memory'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'digital-twin-memory'),
      'Store one consent-scoped memory, recall it, then delete it.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, stores, recalls, deletes, null);
  } catch (error) {
    return Outcome(null, stores, recalls, deletes, error);
  }
}

void test() {
  final success = runMemory(accountId);
  if (success.error != null || success.stores != 1 || success.recalls != 1 || success.deletes != 1) {
    throw StateError('success failed: stores=${success.stores} recalls=${success.recalls} deletes=${success.deletes}');
  }
  final report = success.report!;
  final stored = report['stored'] as Map<String, dynamic>;
  final forgotten = report['forgotten'] as Map<String, dynamic>;
  if (stored['stored'] != true ||
      stored['scope'] != 'work' ||
      stored['consent'] != true ||
      forgotten['deleted'] != true ||
      forgotten['remaining'] != 0 ||
      report['unscoped_recalls'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runMemory('account-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.stores != 0 ||
      denied.recalls != 0 ||
      denied.deletes != 0) {
    throw StateError('scope denial failed: stores=${denied.stores}');
  }

  final failed = runMemory(accountId, simulateFailure: true);
  if (failed.error == null || failed.stores != 1 || failed.recalls != 0 || failed.deletes != 0) {
    throw StateError('dependency failure failed: stores=${failed.stores} recalls=${failed.recalls}');
  }

  print('Dart OG-06 digital-twin-memory tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var account = accountId;
  final index = args.indexOf('--account');
  if (index >= 0 && index + 1 < args.length) account = args[index + 1];
  final outcome = runMemory(account, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('digital twin memory failed: stores=${outcome.stores} recalls=${outcome.recalls} deletes=${outcome.deletes}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
