import 'errors.dart';
import 'hitl.dart';
import 'json.dart';
import 'models.dart';
import 'runtime.dart';

abstract class Model {
  Response generate(Request request);
}

abstract class StreamingModel implements Model {
  Response generateStream(Request request, void Function(String) onDelta);
}

abstract class Tool {
  String get name;
  String get description;
  dynamic invoke(Map<String, dynamic> arguments);
}

class FuncTool implements Tool {
  @override
  final String name;
  @override
  final String description;
  final dynamic Function(Map<String, dynamic>) function;

  FuncTool(this.name, this.description, this.function);

  @override
  dynamic invoke(Map<String, dynamic> arguments) => function(arguments);
}

class Registry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  Tool get(String name) {
    final tool = _tools[name];
    if (tool == null) {
      throw PraxoError('TOOL_NOT_FOUND', 'tool not found: $name');
    }
    return tool;
  }

  List<ToolSpec> specs() {
    final specs = _tools.values
        .map((tool) => ToolSpec(name: tool.name, description: tool.description))
        .toList();
    specs.sort((a, b) => a.name.compareTo(b.name));
    return specs;
  }
}

class StaticModel implements Model {
  final String content;

  StaticModel(this.content);

  @override
  Response generate(Request request) =>
      Response(message: Message.assistant(content));
}

class AgentOptions {
  final Model model;
  Registry? tools;
  EventSink? events;
  Decision Function(Action action)? policy;
  String systemPrompt;
  ContextBudget? context;
  int maxSteps;
  int maxTokens;
  String? toolChoice;
  List<String> allowedTools;
  List<String> interruptOn;
  InterruptHandler? onInterruptDecision;
  InterruptApproval? onInterrupt;
  bool requirePolicy;
  bool requireToolScope;
  void Function(String)? onDelta;

  AgentOptions(
    this.model, {
    this.tools,
    this.events,
    this.policy,
    this.systemPrompt = '',
    this.context,
    this.maxSteps = 8,
    this.maxTokens = 0,
    this.toolChoice,
    this.allowedTools = const [],
    this.interruptOn = const [],
    this.onInterruptDecision,
    this.onInterrupt,
    this.requirePolicy = false,
    this.requireToolScope = false,
    this.onDelta,
  });
}

class Agent {
  final AgentOptions options;

  Agent(this.options) {
    if (options.requirePolicy && options.policy == null) {
      throw const PraxoError(
          'AGENT_INVALID_OPTIONS', 'agent: require policy: policy is required');
    }
    if (options.requireToolScope && options.allowedTools.isEmpty) {
      throw const PraxoError('AGENT_INVALID_OPTIONS',
          'agent: require tool scope: allowedTools must not be empty');
    }
  }

  RunResult run(Session session, String prompt) {
    final maxSteps = options.maxSteps > 0 ? options.maxSteps : 8;
    final runId = 'run-${DateTime.now().millisecondsSinceEpoch}';
    final messages = <Message>[...session.messages];
    if (options.systemPrompt.isNotEmpty) {
      messages.insert(0, Message.text(roleSystem, options.systemPrompt));
    }
    messages.add(Message.text(roleUser, prompt));
    var usage = const Usage();
    _emit('run.started', session.id, runId);
    try {
      for (var step = 1; step <= maxSteps; step++) {
        _authorize(Action(kind: 'model.generate', sessionId: session.id));
        if (options.context != null) {
          final (compacted, ok) = options.context!.compact(messages);
          if (!ok) {
            throw const PraxoError('AGENT_CONTEXT_BUDGET', 'context budget');
          }
          messages
            ..clear()
            ..addAll(compacted);
        }
        final request = Request(
          messages: messages,
          tools: _advertisedTools(),
          toolChoice: options.toolChoice,
        );
        final Response response;
        if (options.onDelta != null) {
          final model = options.model;
          if (model is! StreamingModel) {
            throw const PraxoError(
                'AGENT_STREAM', 'agent: model does not support streaming');
          }
          response = model.generateStream(request, options.onDelta!);
        } else {
          response = options.model.generate(request);
        }
        usage = usage.plus(response.usage);
        if (options.maxTokens > 0 &&
            usage.inputTokens + usage.outputTokens > options.maxTokens) {
          throw const PraxoError('AGENT_MAX_TOKENS', 'token budget');
        }
        final message = response.message;
        messages.add(message);
        if (message.toolCalls.isEmpty) {
          _emit('run.completed', session.id, runId);
          return RunResult(
            runId: runId,
            output: message.content ?? '',
            steps: step,
            usage: usage,
          );
        }
        for (final call in message.toolCalls) {
          messages.add(_invokeTool(call, runId, session.id));
        }
      }
      throw const PraxoError('AGENT_MAX_STEPS', 'maximum steps');
    } catch (error) {
      _emit('run.failed', session.id, runId, {'error': error.toString()});
      rethrow;
    }
  }

  Message _invokeTool(ToolCall call, String runId, String sessionId) {
    final originalName = call.name;
    final originalArguments = call.arguments;
    if (!_toolAllowed(originalName)) {
      throw const PraxoError('AGENT_TOOL_NOT_ALLOWED', 'tool not allowed');
    }
    _authorize(Action(
      kind: 'tool.invoke',
      sessionId: sessionId,
      toolName: originalName,
      arguments: originalArguments,
    ));
    final registry = options.tools;
    if (registry == null) {
      throw const PraxoError('TOOL_NOT_FOUND', 'tool is not registered');
    }
    final (active, skip, result) = _applyInterrupt(call, runId, sessionId);
    if (skip) {
      return Message.tool(Json.stringify(result), active.id);
    }
    if (!_toolAllowed(active.name)) {
      throw const PraxoError('AGENT_TOOL_NOT_ALLOWED', 'tool not allowed');
    }
    if (active.name != originalName ||
        !Json.equals(active.arguments, originalArguments)) {
      _authorize(Action(
        kind: 'tool.invoke',
        sessionId: sessionId,
        toolName: active.name,
        arguments: active.arguments,
      ));
    }
    final tool = registry.get(active.name);
    _emit('tool.call', sessionId, runId, {
      'name': active.name,
      'arguments': active.arguments,
    });
    final value = tool.invoke(active.arguments);
    return Message.tool(Json.stringify(value), active.id);
  }

  (ToolCall, bool, dynamic) _applyInterrupt(
    ToolCall call,
    String runId,
    String sessionId,
  ) {
    if (!options.interruptOn.contains(call.name)) {
      return (call, false, null);
    }
    if (options.onInterruptDecision == null && options.onInterrupt == null) {
      throw PraxoError('AGENT_INTERRUPT_UNHANDLED',
          'agent: approval handler not configured: ${call.name}');
    }
    _emit('tool.interrupt', sessionId, runId, {
      'name': call.name,
      'arguments': call.arguments,
    });
    final interrupt = Interrupt(
      runId: runId,
      sessionId: sessionId,
      call: call,
    );
    final handler = options.onInterruptDecision;
    if (handler != null) {
      final decision = handler(interrupt);
      switch (decision.action) {
        case interruptApprove:
          return (call, false, null);
        case interruptEdit:
          final arguments = decision.arguments;
          if (arguments == null) {
            throw const PraxoError('AGENT_INTERRUPT_DECISION_INVALID',
                'agent: edit requires arguments');
          }
          return (
            ToolCall(
              id: call.id,
              name: call.name,
              arguments: Map<String, dynamic>.from(arguments),
            ),
            false,
            null,
          );
        case interruptReject:
          throw PraxoError(
            'AGENT_APPROVAL_DENIED',
            'agent: tool call denied by approval: ${call.name}: '
                '${decision.reason}',
          );
        case interruptRespond:
          return (call, true, decision.response);
        default:
          throw PraxoError(
            'AGENT_INTERRUPT_DECISION_INVALID',
            'agent: invalid interrupt decision: ${decision.action}',
          );
      }
    }
    final approved = options.onInterrupt!(interrupt);
    if (!approved) {
      throw PraxoError(
        'AGENT_APPROVAL_DENIED',
        'agent: tool call denied by approval: ${call.name}',
      );
    }
    return (call, false, null);
  }

  bool _toolAllowed(String name) =>
      options.allowedTools.isEmpty || options.allowedTools.contains(name);

  List<ToolSpec> _advertisedTools() {
    final specs = options.tools?.specs() ?? const <ToolSpec>[];
    if (options.allowedTools.isEmpty) {
      return specs;
    }
    return specs
        .where((tool) => options.allowedTools.contains(tool.name))
        .toList();
  }

  void _authorize(Action action) {
    final policy = options.policy;
    if (policy == null) return;
    final decision = policy(action);
    if (!decision.allowed) {
      throw PraxoError(
        'AGENT_POLICY_DENIED',
        'agent: ${action.kind} denied: ${decision.reason}',
      );
    }
  }

  void _emit(String type, String sessionId, String runId, [dynamic data]) {
    options.events?.emit(Event(
      type: type,
      sessionId: sessionId,
      runId: runId,
      data: data,
    ));
  }
}

RunResult runAgent(AgentOptions options, Session session, String prompt) =>
    Agent(options).run(session, prompt);
