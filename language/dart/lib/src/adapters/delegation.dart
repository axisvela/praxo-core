import '../errors.dart';

class SubagentRequest {
  final String parentSessionId;
  final String agentId;
  final String prompt;
  final String mode;

  const SubagentRequest({
    required this.parentSessionId,
    required this.agentId,
    required this.prompt,
    this.mode = 'isolated',
  });
}

class SubagentResult {
  final String taskId;
  final String agentId;
  final String output;

  const SubagentResult({
    required this.taskId,
    required this.agentId,
    required this.output,
  });
}

class SubagentTask {
  final String id;
  final String parentSessionId;
  final String agentId;
  final String mode;
  final String status;
  final String output;
  final String error;
  final String createdAt;
  final String updatedAt;

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

typedef SubagentRunner = Future<SubagentResult> Function(
    SubagentRequest request);

class SubagentManager {
  final SubagentRunner runner;

  const SubagentManager(this.runner);

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
