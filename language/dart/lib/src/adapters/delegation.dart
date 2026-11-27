import '../errors.dart';

/// The SubagentRequest API.
class SubagentRequest {
  /// The parentSessionId value.
  final String parentSessionId;
  /// The agentId value.
  final String agentId;
  /// The prompt value.
  final String prompt;
  /// The mode value.
  final String mode;

  /// Creates a SubagentRequest instance.
  const SubagentRequest({
    required this.parentSessionId,
    required this.agentId,
    required this.prompt,
    this.mode = 'isolated',
  });
}

/// The SubagentResult API.
class SubagentResult {
  /// The taskId value.
  final String taskId;
  /// The agentId value.
  final String agentId;
  /// The output value.
  final String output;

  /// Creates a SubagentResult instance.
  const SubagentResult({
    required this.taskId,
    required this.agentId,
    required this.output,
  });
}

/// The SubagentTask API.
class SubagentTask {
  /// The id value.
  final String id;
  /// The parentSessionId value.
  final String parentSessionId;
  /// The agentId value.
  final String agentId;
  /// The mode value.
  final String mode;
  /// The status value.
  final String status;
  /// The output value.
  final String output;
  /// The error value.
  final String error;
  /// The createdAt value.
  final String createdAt;
  /// The updatedAt value.
  final String updatedAt;

  /// Creates a SubagentTask instance.
  const SubagentTask({
    required this.id,
    required this.parentSessionId,
    required this.agentId,
    required this.mode,
    required this.status,
    required this.output,
    required this.error,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Signature for SubagentRunner.
typedef SubagentRunner = Future<SubagentResult> Function(
    SubagentRequest request);

/// The SubagentManager API.
class SubagentManager {
  /// The runner value.
  final SubagentRunner runner;

  /// Creates a SubagentManager instance.
  const SubagentManager(this.runner);

  /// Handles run().
  Future<SubagentTask> run(SubagentRequest request) async {
    if (request.parentSessionId.isEmpty || request.agentId.isEmpty) {
      throw const PraxoError('SUBAGENT_INVALID',
          'agent: subagent parent session and agent id are required');
    }
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final base = SubagentTask(
      id: 'subagent',
      parentSessionId: request.parentSessionId,
      agentId: request.agentId,
      mode: request.mode == 'fork' ? 'fork' : 'isolated',
      status: 'running',
      output: '',
      error: '',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    try {
      final result = await runner(request);
      return SubagentTask(
        id: base.id,
        parentSessionId: base.parentSessionId,
        agentId: base.agentId,
        mode: base.mode,
        status: 'completed',
        output: result.output,
        error: '',
        createdAt: base.createdAt,
        updatedAt: timestamp,
      );
    } on PraxoError catch (error) {
      return SubagentTask(
        id: base.id,
        parentSessionId: base.parentSessionId,
        agentId: base.agentId,
        mode: base.mode,
        status: 'failed',
        output: '',
        error: error.code,
        createdAt: base.createdAt,
        updatedAt: timestamp,
      );
    } catch (_) {
      return SubagentTask(
        id: base.id,
        parentSessionId: base.parentSessionId,
        agentId: base.agentId,
        mode: base.mode,
        status: 'failed',
        output: '',
        error: 'SUBAGENT_ERROR',
        createdAt: base.createdAt,
        updatedAt: timestamp,
      );
    }
  }
}
