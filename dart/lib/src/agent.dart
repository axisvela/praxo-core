import 'errors.dart';
import 'json.dart';
import 'models.dart';
import 'runtime.dart';

abstract class Model {
  Response generate(Request request);
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
  });
}

class Agent {
  final AgentOptions options;

  Agent(this.options);

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
          tools: options.tools?.specs() ?? const [],
          toolChoice: options.toolChoice,
        );
        final response = options.model.generate(request);
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
    _authorize(Action(
      kind: 'tool.invoke',
      sessionId: sessionId,
      toolName: call.name,
      arguments: call.arguments,
    ));
    final registry = options.tools;
    if (registry == null) {
      throw const PraxoError('TOOL_NOT_FOUND', 'tool is not registered');
    }
    final tool = registry.get(call.name);
    _emit('tool.call', sessionId, runId, {
      'name': call.name,
      'arguments': call.arguments,
    });
    final value = tool.invoke(call.arguments);
    return Message.tool(Json.stringify(value), call.id);
  }

  void _authorize(Action action) {
    final policy = options.policy;
    if (policy == null) return;
    if (!policy(action).allowed) {
      throw const PraxoError('POLICY_ERROR', 'policy denied the action');
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
