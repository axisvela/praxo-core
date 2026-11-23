import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const employeeId = 'employee-100';

class FixtureModel implements Model {
  FixtureModel(this.employee);

  final String employee;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'profile-1', name: 'read_profile', arguments: {'employee': employee}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'plan-1', name: 'draft_onboarding', arguments: {
            'employee': employee,
            'action': 'assign_path',
          }),
        ]),
      );
    }
    final profile = jsonDecode(results[0].content ?? '{}');
    final plan = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'stage': 'onboarding_drafted',
        'profile': profile,
        'plan': plan,
        'permissions_granted': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['employee'] == employeeId;
  if (action.toolName == 'read_profile') {
    return Decision(allowed: inScope, reason: 'only employee-100 is in scope');
  }
  if (action.toolName == 'draft_onboarding') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'assign_path',
      reason: 'only an employee-100 assign_path draft is allowed',
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

Outcome runOnboarding(String employee, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_profile', 'Read a fixed employee profile; no writes.', (arguments) {
      if (arguments['employee'] != employeeId) throw Exception('employee not found');
      reads += 1;
      if (simulateFailure) throw Exception('PROFILE_SOURCE_UNAVAILABLE');
      return {
        'employee': employeeId,
        'role': 'engineer',
        'level': 'mid',
        'prerequisites': ['security', 'tooling'],
        'source': 'profile_fixture',
      };
    }))
    ..register(FuncTool('draft_onboarding', 'Draft a review-only learning path; no permissions.', (arguments) {
      drafts += 1;
      return {
        'plan_id': 'onboarding-100',
        'employee': employeeId,
        'action': arguments['action'],
        'lessons': 3,
        'status': 'draft_only',
        'review_required': true,
        'permissions_granted': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(employee),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_profile', 'draft_onboarding'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'onboarding-plan'),
      'Read the fixed profile and draft a review-only onboarding plan.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runOnboarding(employeeId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final profile = report['profile'] as Map<String, dynamic>;
  final plan = report['plan'] as Map<String, dynamic>;
  if (report['stage'] != 'onboarding_drafted' ||
      profile['role'] != 'engineer' ||
      plan['lessons'] != 3 ||
      plan['status'] != 'draft_only' ||
      report['permissions_granted'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runOnboarding('employee-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts}');
  }

  final failed = runOnboarding(employeeId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts}');
  }

  print('Dart OP-06 onboarding-plan tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var employee = employeeId;
  final index = args.indexOf('--employee');
  if (index >= 0 && index + 1 < args.length) employee = args[index + 1];
  final outcome = runOnboarding(employee, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('onboarding failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
