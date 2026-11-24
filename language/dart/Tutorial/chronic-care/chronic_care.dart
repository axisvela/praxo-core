import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const patientId = 'patient-100';

class FixtureModel implements Model {
  FixtureModel(this.patient);

  final String patient;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'trends-1', name: 'read_trends', arguments: {'patient': patient}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'alert-1', name: 'draft_alert', arguments: {
            'patient': patient,
            'action': 'draft_alert',
          }),
        ]),
      );
    }
    final trends = jsonDecode(results[0].content ?? '{}');
    final alert = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'trends': trends,
        'alert': alert,
        'dosage_changes': 0,
        'treatment_changes': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['patient'] == patientId;
  if (action.toolName == 'read_trends') {
    return Decision(allowed: inScope, reason: 'only patient-100 is in scope');
  }
  if (action.toolName == 'draft_alert') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'draft_alert',
      reason: 'only a patient-100 draft_alert is allowed',
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

Outcome runFollowUp(String patient, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_trends', 'Summarize fixed wearable trends; no treatment change.', (arguments) {
      if (arguments['patient'] != patientId) throw Exception('patient not found');
      reads += 1;
      if (simulateFailure) throw Exception('TRENDS_UNAVAILABLE');
      return {
        'patient': patientId,
        'days': 7,
        'resting_hr': 78,
        'threshold': 75,
        'trend': 'rising',
        'alert': true,
        'source': 'trends_fixture',
      };
    }))
    ..register(FuncTool('draft_alert', 'Route a review-only alert; no dosage or treatment change.', (arguments) {
      drafts += 1;
      return {
        'alert_id': 'chronic-100',
        'patient': patientId,
        'action': arguments['action'],
        'routed_to': 'care_team',
        'status': 'draft_only',
        'review_required': true,
        'dosage_changes': 0,
        'treatment_changes': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(patient),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_trends', 'draft_alert'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'chronic-care'),
      'Summarize the fixed trends and draft a review-only care alert.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runFollowUp(patientId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final trends = report['trends'] as Map<String, dynamic>;
  final alert = report['alert'] as Map<String, dynamic>;
  if (trends['resting_hr'] != 78 ||
      trends['trend'] != 'rising' ||
      trends['alert'] != true ||
      alert['status'] != 'draft_only' ||
      alert['routed_to'] != 'care_team' ||
      report['dosage_changes'] != 0 ||
      report['treatment_changes'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runFollowUp('patient-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts}');
  }

  final failed = runFollowUp(patientId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts}');
  }

  print('Dart HC-02 chronic-care tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var patient = patientId;
  final index = args.indexOf('--patient');
  if (index >= 0 && index + 1 < args.length) patient = args[index + 1];
  final outcome = runFollowUp(patient, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('chronic care failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
