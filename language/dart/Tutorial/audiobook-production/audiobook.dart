import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const bookId = 'book-100';

class FixtureModel implements Model {
  FixtureModel(this.book);

  final String book;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'book-1', name: 'read_book', arguments: {'book': book}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'production-1', name: 'draft_production', arguments: {
            'book': book,
            'action': 'draft_production',
          }),
        ]),
      );
    }
    final snapshot = jsonDecode(results[0].content ?? '{}');
    final plan = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'stage': 'audiobook_plan_drafted',
        'book': snapshot,
        'plan': plan,
        'synthesized_audio': false,
        'rights_claims': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['book'] == bookId;
  if (action.toolName == 'read_book') {
    return Decision(allowed: inScope, reason: 'only book-100 is in scope');
  }
  if (action.toolName == 'draft_production') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'draft_production',
      reason: 'only a book-100 draft_production is allowed',
    );
  }
  return const Decision(allowed: false, reason: 'unsupported tool');
}

class Outcome {
  Outcome(this.report, this.reads, this.drafts, this.error);

  final Map<String, dynamic>? report;
  final int reads;
  final int drafts;
  final Object? error;
}

Outcome runProduction(String book, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_book', 'Read a fixed licensed book fixture; no audio access.', (arguments) {
      if (arguments['book'] != bookId) throw Exception('book not found');
      reads += 1;
      if (simulateFailure) throw Exception('BOOK_INDEX_UNAVAILABLE');
      return {
        'book': bookId,
        'chapters': 12,
        'characters': 3,
        'licensed': true,
        'cues': 8,
        'source': 'book_fixture',
      };
    }))
    ..register(FuncTool('draft_production', 'Draft a review-only production plan; never synthesizes audio.', (arguments) {
      drafts += 1;
      return {
        'plan_id': 'audiobook-100',
        'book': bookId,
        'action': arguments['action'],
        'segments': 12,
        'status': 'draft_only',
        'review_required': true,
        'synthesized_audio': false,
        'rights_claims': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(book),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_book', 'draft_production'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'audiobook-production'),
      'Read the fixed book and draft a review-only production plan.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runProduction(bookId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final snapshot = report['book'] as Map<String, dynamic>;
  final plan = report['plan'] as Map<String, dynamic>;
  if (snapshot['chapters'] != 12 ||
      snapshot['licensed'] != true ||
      snapshot['characters'] != 3 ||
      plan['segments'] != 12 ||
      plan['status'] != 'draft_only' ||
      plan['synthesized_audio'] != false ||
      report['rights_claims'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runProduction('book-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts}');
  }

  final failed = runProduction(bookId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts}');
  }

  print('Dart MD-06 audiobook-production tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var book = bookId;
  final index = args.indexOf('--book');
  if (index >= 0 && index + 1 < args.length) book = args[index + 1];
  final outcome = runProduction(book, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('audiobook production failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
