import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const tripId = 'trip-100';
const farePrice = 640;
const seatsLeft = 4;

class FixtureModel implements Model {
  FixtureModel(this.trip);

  final String trip;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'inventory-1', name: 'check_inventory', arguments: {'trip': trip}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'booking-1', name: 'draft_booking', arguments: {
            'trip': trip,
            'action': 'hold_fare',
          }),
        ]),
      );
    }
    final inventory = jsonDecode(results[0].content ?? '{}');
    final booking = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'inventory': inventory,
        'booking': booking,
        'payments': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['trip'] == tripId;
  if (action.toolName == 'check_inventory') {
    return Decision(allowed: inScope, reason: 'only trip-100 is in scope');
  }
  if (action.toolName == 'draft_booking') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'hold_fare',
      reason: 'only a trip-100 hold_fare draft is allowed',
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

Outcome runBooking(String trip, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('check_inventory', 'Read fixed fare inventory; no payment.', (arguments) {
      if (arguments['trip'] != tripId) throw Exception('trip not found');
      reads += 1;
      if (simulateFailure) throw Exception('INVENTORY_UNAVAILABLE');
      return {
        'trip': tripId,
        'route': 'AMS-SIN',
        'price': farePrice,
        'seats_left': seatsLeft,
        'refundable': true,
        'source': 'inventory_fixture',
      };
    }))
    ..register(FuncTool('draft_booking', 'Draft a review-only fare hold; never pays or tickets.', (arguments) {
      drafts += 1;
      return {
        'booking_id': 'booking-100',
        'trip': tripId,
        'action': arguments['action'],
        'price': farePrice,
        'status': 'draft_only',
        'review_required': true,
        'payments': 0,
        'tickets': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(trip),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['check_inventory', 'draft_booking'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'travel-booking'),
      'Check fixed inventory and draft a review-only fare hold.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runBooking(tripId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final inventory = report['inventory'] as Map<String, dynamic>;
  final booking = report['booking'] as Map<String, dynamic>;
  if (inventory['seats_left'] != 4 ||
      inventory['price'] != 640 ||
      booking['status'] != 'draft_only' ||
      report['payments'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runBooking('trip-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed');
  }

  final failed = runBooking(tripId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed');
  }

  print('Dart PE-02 travel-booking tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var trip = tripId;
  final index = args.indexOf('--trip');
  if (index >= 0 && index + 1 < args.length) trip = args[index + 1];
  final outcome = runBooking(trip, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('travel booking failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
