import 'models.dart';

/// The interruptApprove value.
const String interruptApprove = 'approve';
/// The interruptEdit value.
const String interruptEdit = 'edit';
/// The interruptReject value.
const String interruptReject = 'reject';
/// The interruptRespond value.
const String interruptRespond = 'respond';

/// A human-in-the-loop interrupt.
class Interrupt {
  /// The runId value.
  final String runId;
  /// The sessionId value.
  final String sessionId;
  /// The call value.
  final ToolCall call;

  /// Creates a Interrupt instance.
  const Interrupt({
    required this.runId,
    required this.sessionId,
    required this.call,
  });
}

/// A decision for a human-in-the-loop interrupt.
class InterruptDecision {
  /// The action value.
  final String action;
  /// The String value.
  final Map<String, dynamic>? arguments;
  /// The response value.
  final String response;
  /// The reason value.
  final String reason;

  /// Creates a InterruptDecision instance.
  const InterruptDecision({
    required this.action,
    this.arguments,
    this.response = '',
    this.reason = '',
  });
}

/// Signature for InterruptHandler.
typedef InterruptHandler = InterruptDecision Function(Interrupt interrupt);
/// Signature for InterruptApproval.
typedef InterruptApproval = bool Function(Interrupt interrupt);
