import 'models.dart';

const String interruptApprove = 'approve';
const String interruptEdit = 'edit';
const String interruptReject = 'reject';
const String interruptRespond = 'respond';

class Interrupt {
  final String runId;
  final String sessionId;
  final ToolCall call;

  const Interrupt({
    required this.runId,
    required this.sessionId,
    required this.call,
  });
}

class InterruptDecision {
  final String action;
  final Map<String, dynamic>? arguments;
  final String response;
  final String reason;

  const InterruptDecision({
    required this.action,
    this.arguments,
    this.response = '',
    this.reason = '',
  });
}

typedef InterruptHandler = InterruptDecision Function(Interrupt interrupt);
typedef InterruptApproval = bool Function(Interrupt interrupt);
