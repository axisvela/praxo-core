const roleSystem = 'system';
const roleUser = 'user';
const roleAssistant = 'assistant';
const roleTool = 'tool';
const streamKinds = ['values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint'];

class ContentBlock {
  final String type;
  final String? text;
  final String? imageUrl;
  final String? data;

  const ContentBlock({this.type = 'text', this.text, this.imageUrl, this.data});

  Map<String, dynamic> wire() {
    final out = <String, dynamic>{'type': type};
    if (text != null) out['text'] = text;
    if (imageUrl != null) out['image_url'] = imageUrl;
    if (data != null) out['data'] = data;
    return out;
  }
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({this.id = '', this.name = '', this.arguments = const {}});

  Map<String, dynamic> wire() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };
}

class Message {
  final String role;
  final String? content;
  final List<ContentBlock> contentBlocks;
  final List<ToolCall> toolCalls;
  final String? toolId;

  const Message({
    required this.role,
    this.content,
    this.contentBlocks = const [],
    this.toolCalls = const [],
    this.toolId,
  });

  factory Message.text(String role, String content) =>
      Message(role: role, content: content);

  factory Message.assistant(String content, [List<ToolCall> toolCalls = const []]) =>
      Message(role: roleAssistant, content: content, toolCalls: toolCalls);

  factory Message.tool(String content, String toolId) =>
      Message(role: roleTool, content: content, toolId: toolId);
}

class ToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic>? parameters;
  final String? risk;

  const ToolSpec({
    required this.name,
    this.description = '',
    this.parameters,
    this.risk,
  });
}

class Usage {
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;

  const Usage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedTokens = 0,
  });

  Usage plus(Usage other) => Usage(
        inputTokens: inputTokens + other.inputTokens,
        outputTokens: outputTokens + other.outputTokens,
        cachedTokens: cachedTokens + other.cachedTokens,
      );
}

class Request {
  final List<Message> messages;
  final List<ToolSpec> tools;
  final String? toolChoice;
  final dynamic responseFormat;
  final double temperature;

  const Request({
    this.messages = const [],
    this.tools = const [],
    this.toolChoice,
    this.responseFormat,
    this.temperature = 0,
  });
}

class Response {
  final Message message;
  final Usage usage;
  final String? finishReason;

  const Response({
    required this.message,
    this.usage = const Usage(),
    this.finishReason,
  });
}

class Session {
  final String id;
  final List<Message> messages;

  const Session({required this.id, this.messages = const []});
}

class RunResult {
  final String runId;
  final String output;
  final int steps;
  final Usage usage;

  const RunResult({
    this.runId = '',
    this.output = '',
    this.steps = 0,
    this.usage = const Usage(),
  });
}

class MemoryRecord {
  String id;
  final String frame;
  final String content;
  String? createdAt;

  MemoryRecord({
    this.id = '',
    this.frame = '',
    this.content = '',
    this.createdAt,
  });
}

class PathGrant {
  final String root;
  final String access;

  const PathGrant({required this.root, this.access = 'read'});
}

class Action {
  final String kind;
  final String sessionId;
  final String? toolName;
  final Map<String, dynamic>? arguments;

  const Action({
    required this.kind,
    required this.sessionId,
    this.toolName,
    this.arguments,
  });
}

class Decision {
  final bool allowed;
  final String reason;

  const Decision({this.allowed = false, this.reason = ''});
}

class Event {
  final String type;
  final String sessionId;
  final String? runId;
  final dynamic data;

  const Event({
    required this.type,
    required this.sessionId,
    this.runId,
    this.data,
  });
}

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
