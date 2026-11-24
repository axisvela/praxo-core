import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const campaignId = 'campaign-100';
const customers = [600, 200, 700];

class FixtureModel implements Model {
  FixtureModel(this.campaign);

  final String campaign;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'segments-1', name: 'read_segments', arguments: {'campaign': campaign}),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(id: 'campaign-1', name: 'draft_campaign', arguments: {
            'campaign': campaign,
            'action': 'review_campaign',
          }),
        ]),
      );
    }
    final segments = jsonDecode(results[0].content ?? '{}');
    final draft = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'segments': segments,
        'campaign': draft,
        'sends': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') return const Decision(allowed: true);
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['campaign'] == campaignId;
  if (action.toolName == 'read_segments') {
    return Decision(allowed: inScope, reason: 'only campaign-100 is in scope');
  }
  if (action.toolName == 'draft_campaign') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'review_campaign',
      reason: 'only a review-only campaign draft is allowed',
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

Outcome runSegments(String campaign, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool('read_segments', 'Compute fixed customer segments; no customer data access.', (arguments) {
      if (arguments['campaign'] != campaignId) throw Exception('campaign not found');
      reads += 1;
      if (simulateFailure) throw Exception('SEGMENT_DATA_UNAVAILABLE');
      final high = customers.where((value) => value >= 500).length;
      return {
        'campaign': campaignId,
        'customers': customers.length,
        'high_value': high,
        'average_spend': customers.reduce((a, b) => a + b) / customers.length,
        'source': 'segment_fixture',
      };
    }))
    ..register(FuncTool('draft_campaign', 'Draft a review-only campaign; never sends messages.', (arguments) {
      drafts += 1;
      return {
        'campaign_id': 'campaign-draft-100',
        'campaign': campaignId,
        'action': arguments['action'],
        'status': 'draft_only',
        'review_required': true,
        'sends': 0,
      };
    }));
  final options = AgentOptions(
    FixtureModel(campaign),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_segments', 'draft_campaign'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'marketing-segments'),
      'Compute fixed segments and draft a review-only campaign.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(decoded is Map<String, dynamic> ? decoded : null, reads, drafts, null);
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runSegments(campaignId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts}');
  }
  final report = success.report!;
  final segments = report['segments'] as Map<String, dynamic>;
  final campaign = report['campaign'] as Map<String, dynamic>;
  if (segments['high_value'] != 2 ||
      segments['average_spend'] != 500 ||
      campaign['status'] != 'draft_only' ||
      report['sends'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runSegments('campaign-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed');
  }

  final failed = runSegments(campaignId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed');
  }

  print('Dart CS-04 marketing-segments tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var campaign = campaignId;
  final index = args.indexOf('--campaign');
  if (index >= 0 && index + 1 < args.length) campaign = args[index + 1];
  final outcome = runSegments(campaign, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln('marketing segments failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}');
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
