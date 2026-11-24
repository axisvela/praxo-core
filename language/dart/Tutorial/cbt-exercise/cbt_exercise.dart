import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const sessionId = 'session-100';

class FixtureModel implements Model {
  FixtureModel(this.session);

  final String session;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'exercise-1', name: 'read_exercise', arguments: {'session': session}),
        ]),
      );
    }
    if (results.length == 1) {
      final exercise = jsonDecode(results[0].content ?? '{}') as Map<String, dynamic>;
      final action = exercise['crisis_flag'] == true ? 'draft_summary_escalated' : 'draft_summary';
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'summary-1', name: 'draft_summary', arguments: {
            'session': session,
            'action': action,
          }),
        ]),
      );
    }
    final exercise = jsonDecode(results[0].content ?? '{}');
    final summary = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'exercise': exercise,
        'summary': summary,
        'therapist_replacement': 0,
        'unsupervised_crisis': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['session'] == sessionId;
  if (action.toolName == 'read_exercise') {
    return Decision(allowed: inScope, reason: 'only session-100 is in scope');
  }
  if (action.toolName == 'draft_summary') {
    final choice = action.arguments?['action'];
    return Decision(
      allowed: inScope && (choice == 'draft_summary' || choice == 'draft_summary_escalated'),
      reason: 'only a review-only summary draft is allowed',
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

Outcome runExercise(String session, {bool crisis = false, bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_exercise', 'Read a fixed CBT exercise and crisis flag.', (arguments) {
      if (arguments['session'] != sessionId) throw Exception('session not found');
      reads += 1;
      if (simulateFailure) throw Exception('EXERCISE_INDEX_UNAVAILABLE');
      return {
        'session': sessionId,
        'exercise': 'breathing',
        'steps': 3,
        'crisis_flag': crisis,
        'escalation': 'human_review',
        'source': 'exercise_fixture',
      };
    }))
    ..register(FuncTool('draft_summary', 'Draft review-only summary; never replaces a therapist.', (arguments) {
      drafts += 1;
      return {
        'summary_id': 'cbt-100',
        'session': sessionId,
        'action': arguments['action'],
        'escalated': arguments['action'] == 'draft_summary_escalated',
        'status': 'draft_only',
        'review_required': true,
        'therapist_replacement': 0,
        'unsupervised_crisis': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(session),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_exercise', 'draft_summary'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'cbt-exercise'),
      'Read the fixed exercise and draft a review-only summary.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runExercise(sessionId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final exercise = report['exercise'] as Map<String, dynamic>;
  final summary = report['summary'] as Map<String, dynamic>;
  if (exercise['crisis_flag'] != false ||
      exercise['steps'] != 3 ||
      summary['status'] != 'draft_only' ||
      summary['escalated'] != false ||
      report['therapist_replacement'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final crisis = runExercise(sessionId, crisis: true);
  if (crisis.error != null || crisis.reads != 1 || crisis.drafts != 1) {
    throw StateError('crisis path failed: reads=${crisis.reads} drafts=${crisis.drafts}');
  }
  final crisisReport = crisis.report!;
  if ((crisisReport['exercise'] as Map<String, dynamic>)['crisis_flag'] != true ||
      (crisisReport['exercise'] as Map<String, dynamic>)['escalation'] != 'human_review' ||
      (crisisReport['summary'] as Map<String, dynamic>)['escalated'] != true) {
    throw StateError('crisis escalation missing: $crisisReport');
  }

  final denied = runExercise('session-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts}');
  }

  final failed = runExercise(sessionId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts}');
  }

  print('Dart HC-05 cbt-exercise tutorial: success, crisis, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var session = sessionId;
  final index = args.indexOf('--session');
  if (index >= 0 && index + 1 < args.length) session = args[index + 1];
  final outcome = runExercise(
    session,
    crisis: args.contains('--crisis'),
    simulateFailure: args.contains('--simulate-failure'),
  );
  if (outcome.error != null) {
    stderr.writeln('CBT exercise failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
