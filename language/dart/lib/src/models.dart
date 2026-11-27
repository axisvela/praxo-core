/// The roleSystem value.
const roleSystem = 'system';
/// The roleUser value.
const roleUser = 'user';
/// The roleAssistant value.
const roleAssistant = 'assistant';
/// The roleTool value.
const roleTool = 'tool';
/// The streamKinds value.
const streamKinds = ['values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint'];

/// The ContentBlock API.
class ContentBlock {
  /// The type value.
  final String type;
  /// The text value.
  final String? text;
  /// The imageUrl value.
  final String? imageUrl;
  /// The data value.
  final String? data;

  /// Creates a ContentBlock instance.
  const ContentBlock({this.type = 'text', this.text, this.imageUrl, this.data});

  /// Handles wire().
  Map<String, dynamic> wire() {
    final out = <String, dynamic>{'type': type};
    if (text != null) out['text'] = text;
    if (imageUrl != null) out['image_url'] = imageUrl;
    if (data != null) out['data'] = data;
    return out;
  }
}

/// The ToolCall API.
class ToolCall {
  /// The id value.
  final String id;
  /// The name value.
  final String name;
  /// The String value.
  final Map<String, dynamic> arguments;

  /// Creates a ToolCall instance.
  const ToolCall({this.id = '', this.name = '', this.arguments = const {}});

  /// Handles wire().
  Map<String, dynamic> wire() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };
}

/// The Message API.
class Message {
  /// The role value.
  final String role;
  /// The content value.
  final String? content;
  /// The contentBlocks value.
  final List<ContentBlock> contentBlocks;
  /// The toolCalls value.
  final List<ToolCall> toolCalls;
  /// The toolId value.
  final String? toolId;

  /// Creates a Message instance.
  const Message({
    required this.role,
    this.content,
    this.contentBlocks = const [],
    this.toolCalls = const [],
    this.toolId,
  });

  /// Creates a Message instance.
  factory Message.text(String role, String content) =>
      Message(role: role, content: content);

  /// Creates a Message instance.
  factory Message.assistant(String content, [List<ToolCall> toolCalls = const []]) =>
      Message(role: roleAssistant, content: content, toolCalls: toolCalls);

  /// Creates a Message instance.
  factory Message.tool(String content, String toolId) =>
      Message(role: roleTool, content: content, toolId: toolId);
}

/// The ToolSpec API.
class ToolSpec {
  /// The name value.
  final String name;
  /// The description value.
  final String description;
  /// The String value.
  final Map<String, dynamic>? parameters;
  /// The risk value.
  final String? risk;

  /// Creates a ToolSpec instance.
  const ToolSpec({
    required this.name,
    this.description = '',
    this.parameters,
    this.risk,
  });
}

/// The Usage API.
class Usage {
  /// The inputTokens value.
  final int inputTokens;
  /// The outputTokens value.
  final int outputTokens;
  /// The cachedTokens value.
  final int cachedTokens;

  /// Creates a Usage instance.
  const Usage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedTokens = 0,
  });

  /// Handles plus().
  Usage plus(Usage other) => Usage(
        inputTokens: inputTokens + other.inputTokens,
        outputTokens: outputTokens + other.outputTokens,
        cachedTokens: cachedTokens + other.cachedTokens,
      );
}

/// The Request API.
class Request {
  /// The messages value.
  final List<Message> messages;
  /// The tools value.
  final List<ToolSpec> tools;
  /// The toolChoice value.
  final String? toolChoice;
  /// The responseFormat value.
  final dynamic responseFormat;
  /// The temperature value.
  final double temperature;

  /// Creates a Request instance.
  const Request({
    this.messages = const [],
    this.tools = const [],
    this.toolChoice,
    this.responseFormat,
    this.temperature = 0,
  });
}

/// The Response API.
class Response {
  /// The message value.
  final Message message;
  /// The usage value.
  final Usage usage;
  /// The finishReason value.
  final String? finishReason;

  /// Creates a Response instance.
  const Response({
    required this.message,
    this.usage = const Usage(),
    this.finishReason,
  });
}

/// A conversation session.
class Session {
  /// The id value.
  final String id;
  /// The messages value.
  final List<Message> messages;

  /// Creates a Session instance.
  const Session({required this.id, this.messages = const []});
}

/// The result of an agent run.
class RunResult {
  /// The runId value.
  final String runId;
  /// The output value.
  final String output;
  /// The steps value.
  final int steps;
  /// The usage value.
  final Usage usage;

  /// Creates a RunResult instance.
  const RunResult({
    this.runId = '',
    this.output = '',
    this.steps = 0,
    this.usage = const Usage(),
  });
}

/// A stored memory record.
class MemoryRecord {
  /// The id value.
  String id;
  /// The frame value.
  final String frame;
  /// The content value.
  final String content;
  /// The createdAt value.
  String? createdAt;

  /// Creates a MemoryRecord instance.
  MemoryRecord({
    this.id = '',
    this.frame = '',
    this.content = '',
    this.createdAt,
  });
}

/// A granted path scope.
class PathGrant {
  /// The root value.
  final String root;
  /// The access value.
  final String access;

  /// Creates a PathGrant instance.
  const PathGrant({required this.root, this.access = 'read'});
}

/// An action evaluated by a policy hook.
class Action {
  /// The action kind.
  final String kind;
  /// The sessionId value.
  final String sessionId;
  /// The toolName value.
  final String? toolName;
  /// The String value.
  final Map<String, dynamic>? arguments;

  /// Creates a Action instance.
  const Action({
    required this.kind,
    required this.sessionId,
    this.toolName,
    this.arguments,
  });
}

/// A policy decision for an action.
class Decision {
  /// The allowed value.
  final bool allowed;
  /// The reason value.
  final String reason;

  /// Creates a Decision instance.
  const Decision({this.allowed = false, this.reason = ''});
}

/// A runtime event emitted by the agent loop.
class Event {
  /// The type value.
  final String type;
  /// The sessionId value.
  final String sessionId;
  /// The runId value.
  final String? runId;
  /// The data value.
  final dynamic data;

  /// Creates a Event instance.
  const Event({
    required this.type,
    required this.sessionId,
    this.runId,
    this.data,
  });
}

/// Handles messageWire().
Map<String, dynamic> messageWire(Message message) {
  final out = <String, dynamic>{'role': message.role};
  if (message.content != null) out['content'] = message.content;
  if (message.contentBlocks.isNotEmpty) {
    out['contentBlocks'] = message.contentBlocks.map((block) => block.wire()).toList();
  }
  if (message.toolCalls.isNotEmpty) {
    out['toolCalls'] = message.toolCalls.map((call) => call.wire()).toList();
  }
  if (message.toolId != null) out['toolId'] = message.toolId;
  return out;
}
