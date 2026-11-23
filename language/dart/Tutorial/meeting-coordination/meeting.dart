import 'dart:convert';
import 'dart:io';

import '../../lib/praxo_core.dart';

const meetingId = 'meeting-100';

class FixtureModel implements Model {
  FixtureModel(this.meeting);

  final String meeting;

  @override
  Response generate(Request request) {
    final results = request.messages.where((m) => m.role == roleTool).toList();
    if (results.isEmpty) {
      return Response(
        message: Message.assistant('', [
          ToolCall(
            id: 'calendar-1',
            name: 'read_calendar',
            arguments: {'meeting': meeting},
          ),
        ]),
      );
    }
    if (results.length == 1) {
      return Response(
        message: Message.assistant('', [
          ToolCall(
            id: 'minutes-1',
            name: 'draft_minutes',
            arguments: {'meeting': meeting, 'action': 'share_minutes'},
          ),
        ]),
      );
    }
    final calendar = jsonDecode(results[0].content ?? '{}');
    final minutes = jsonDecode(results[1].content ?? '{}');
    return Response(
      message: Message.assistant(jsonEncode({
        'stage': 'minutes_drafted',
        'calendar': calendar,
        'minutes': minutes,
        'invites_sent': 0,
      })),
    );
  }
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') {
    return const Decision(allowed: true);
  }
  if (action.kind != 'tool.invoke') {
    return const Decision(allowed: false, reason: 'unsupported action');
  }
  final inScope = action.arguments?['meeting'] == meetingId;
  if (action.toolName == 'read_calendar') {
    return Decision(
      allowed: inScope,
      reason: 'only meeting-100 is in scope',
    );
  }
  if (action.toolName == 'draft_minutes') {
    return Decision(
      allowed: inScope && action.arguments?['action'] == 'share_minutes',
      reason: 'only a meeting-100 share_minutes draft is allowed',
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

Outcome runMeeting(String meeting, {bool simulateFailure = false}) {
  var reads = 0;
  var drafts = 0;
  final registry = Registry()
    ..register(FuncTool(
      'read_calendar',
      'Read a fixed meeting calendar fixture; no writes.',
      (arguments) {
        if (arguments['meeting'] != meetingId) {
          throw Exception('meeting not found');
        }
        reads += 1;
        if (simulateFailure) {
          throw Exception('CALENDAR_UNAVAILABLE');
        }
        return {
          'meeting_id': meetingId,
          'slot': '2026-12-02T10:00Z',
          'attendees': 3,
          'conflicts': 0,
          'source': 'calendar_fixture',
        };
      },
    ))
    ..register(FuncTool(
      'draft_minutes',
      'Draft minutes and tasks for human review; never sends invitations.',
      (arguments) {
        drafts += 1;
        return {
          'minutes_id': 'minutes-100',
          'meeting_id': meetingId,
          'action': arguments['action'],
          'status': 'draft_only',
          'review_required': true,
          'invites_sent': 0,
        };
      },
    ));
  final options = AgentOptions(
    FixtureModel(meeting),
    tools: registry,
    maxSteps: 4,
    allowedTools: const ['read_calendar', 'draft_minutes'],
    policy: authorize,
    requirePolicy: true,
    requireToolScope: true,
  );
  try {
    final result = runAgent(
      options,
      Session(id: 'meeting-coordination'),
      'Reconcile the fixed calendar and draft review-only minutes.',
    );
    final decoded = jsonDecode(result.output);
    return Outcome(
      decoded is Map<String, dynamic> ? decoded : null,
      reads,
      drafts,
      null,
    );
  } catch (error) {
    return Outcome(null, reads, drafts, error);
  }
}

void test() {
  final success = runMeeting(meetingId);
  if (success.error != null || success.reads != 1 || success.drafts != 1) {
    throw StateError('success failed: reads=${success.reads} drafts=${success.drafts} error=${success.error}');
  }
  final report = success.report!;
  final calendar = report['calendar'] as Map<String, dynamic>;
  final minutes = report['minutes'] as Map<String, dynamic>;
  if (report['stage'] != 'minutes_drafted' ||
      calendar['conflicts'] != 0 ||
      minutes['status'] != 'draft_only' ||
      report['invites_sent'] != 0) {
    throw StateError('unexpected report: $report');
  }

  final denied = runMeeting('meeting-200');
  if (denied.error is! PraxoError ||
      (denied.error as PraxoError).code != 'AGENT_POLICY_DENIED' ||
      denied.reads != 0 ||
      denied.drafts != 0) {
    throw StateError('scope denial failed: reads=${denied.reads} drafts=${denied.drafts} error=${denied.error}');
  }

  final failed = runMeeting(meetingId, simulateFailure: true);
  if (failed.error == null || failed.reads != 1 || failed.drafts != 0) {
    throw StateError('dependency failure failed: reads=${failed.reads} drafts=${failed.drafts} error=${failed.error}');
  }

  print('Dart OP-02 meeting-coordination tutorial: success, denial and dependency failure passed');
}

void main(List<String> args) {
  if (args.contains('--test')) {
    test();
    return;
  }
  var meeting = meetingId;
  final index = args.indexOf('--meeting');
  if (index >= 0 && index + 1 < args.length) {
    meeting = args[index + 1];
  }
  final outcome = runMeeting(meeting, simulateFailure: args.contains('--simulate-failure'));
  if (outcome.error != null) {
    stderr.writeln(
      'meeting coordination failed: reads=${outcome.reads} drafts=${outcome.drafts}; ${outcome.error}',
    );
    exit(1);
  }
  print(jsonEncode(outcome.report));
}
