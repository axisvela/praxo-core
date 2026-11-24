import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const routeId = 'route-100';

class FixtureModel implements Model {
  FixtureModel(this.route);

  final String route;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'route-1', name: 'read_route', arguments: {'route': route}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'schedule-1', name: 'draft_schedule', arguments: {
            'route': route,
            'action': 'draft_route',
          }),
        ]),
      );
    }
    final snapshot = jsonDecode(results[0].content ?? '{}');
    final schedule = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'snapshot': snapshot,
        'schedule': schedule,
        'vehicle_commands': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['route'] == routeId;
  if (action.toolName == 'read_route') {
    return Decision(allowed: inScope, reason: 'only route-100 is in scope');
  }
  if (action.toolName == 'draft_schedule') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'draft_route',
      reason: 'only a route-100 draft_route is allowed',
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

Outcome runCollection(String route, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_route', 'Read a fixed collection queue; no vehicle access.', (arguments) {
      if (arguments['route'] != routeId) throw Exception('route not found');
      reads += 1;
      if (simulateFailure) throw Exception('ROUTE_INDEX_UNAVAILABLE');
      return {
        'route': routeId,
        'stops': 12,
        'vehicles': 2,
        'capacity_ok': true,
        'source': 'route_fixture',
      };
    }))
    ..register(FuncTool('draft_schedule', 'Draft a review-only collection schedule; never commands vehicles.', (arguments) {
      drafts += 1;
      return {
        'schedule_id': 'collection-100',
        'route': routeId,
        'action': arguments['action'],
        'assigned_stops': 12,
        'status': 'draft_only',
        'review_required': true,
        'vehicle_commands': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(route),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_route', 'draft_schedule'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'waste-collection'),
      'Read the fixed collection queue and draft a review-only schedule.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runCollection(routeId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final snapshot = report['snapshot'] as Map<String, dynamic>;
  final schedule = report['schedule'] as Map<String, dynamic>;
  if (snapshot['stops'] != 12 ||
      snapshot['capacity_ok'] != true ||
      schedule['assigned_stops'] != 12 ||
      schedule['status'] != 'draft_only' ||
      report['vehicle_commands'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runCollection('route-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts}');
  }

  final failed = runCollection(routeId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts}');
  }

  print('Dart CT-06 waste-collection tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var route = routeId;
  final index = args.indexOf('--route');
  if (index >= 0 && index + 1 < args.length) route = args[index + 1];
  final outcome = runCollection(route, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('waste collection failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
