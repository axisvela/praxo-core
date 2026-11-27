import '../agent.dart';
import '../errors.dart';
import '../json.dart';
import '../models.dart';
import 'provider_http.dart';

/// Signature for AnthropicSyncTransport.
typedef AnthropicSyncTransport = dynamic Function(
    String path, Map<String, dynamic> payload);
/// Signature for AnthropicAsyncTransport.
typedef AnthropicAsyncTransport = Future<dynamic> Function(
    String path, Map<String, dynamic> payload);

/// The AnthropicModel API.
class AnthropicModel implements StreamingModel {
  /// The baseUrl value.
  final String baseUrl;
  /// The model value.
  final String model;
  /// The apiKey value.
  final String? apiKey;
  /// The version value.
  final String version;
  /// The maxTokens value.
  final int maxTokens;
  /// The transport value.
  final AnthropicSyncTransport? transport;
  /// The asyncTransport value.
  final AnthropicAsyncTransport? asyncTransport;
  /// The streamTransport value.
  final dynamic Function(String path, Map<String, dynamic> payload)?
      streamTransport;
  /// The timeout value.
  final Duration timeout;

  /// Creates a AnthropicModel instance.
  AnthropicModel({
    this.baseUrl = 'https://api.anthropic.com',
    required this.model,
    this.apiKey,
    this.version = '2023-06-01',
    this.maxTokens = 1024,
    this.transport,
    this.asyncTransport,
    this.streamTransport,
    this.timeout = const Duration(seconds: 60),
  });

  Response generate(Request request) {
    _validate();
    final payload = buildPayload(request);
    final data = transport != null
        ? transport!('/v1/messages', payload)
        : postSync(
            uri: Uri.parse('${_root()}/v1/messages'),
            payload: payload,
            headers: _headers(),
            timeout: timeout,
          );
    return parseResponse(data);
  }

  /// Handles generateAsync().
  Future<Response> generateAsync(Request request) async {
    _validate();
    final payload = buildPayload(request);
    final data = asyncTransport != null
        ? await asyncTransport!('/v1/messages', payload)
        : await postAsync(
            uri: Uri.parse('${_root()}/v1/messages'),
            payload: payload,
            headers: _headers(),
            timeout: timeout,
          );
    return parseResponse(data);
  }

  @override
  Response generateStream(Request request, void Function(String) onDelta) {
    _validate();
    final payload = buildPayload(request)..['stream'] = true;
    final String text;
    if (streamTransport != null) {
      final value = streamTransport!('/v1/messages', payload);
      if (value is! String) {
        throw const PraxoError(
            'PROVIDER_HTTP', 'anthropic: stream transport must return SSE text');
      }
      text = value;
    } else {
      text = postTextSync(
        uri: Uri.parse('${_root()}/v1/messages'),
        payload: payload,
        headers: {..._headers(), 'Accept': 'text/event-stream'},
        timeout: timeout,
      );
    }
    return parseStream(text, onDelta);
  }

  /// Handles parseStream().
  Response parseStream(String text, void Function(String) onDelta) {
    final content = StringBuffer();
    final calls = <int, Map<String, String>>{};
    var inputTokens = 0;
    var outputTokens = 0;
    var cachedTokens = 0;
    String? stopReason;
    var stopped = false;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('data:')) continue;
      final chunk = line.substring(5).trim();
      if (chunk.isEmpty) continue;
      dynamic event;
      try {
        event = Json.parse(chunk);
      } on FormatException {
        throw const PraxoError('MODEL_STREAM', 'anthropic: invalid stream chunk');
      }
      if (event is! Map) continue;
      switch (event['type']) {
        case 'message_start':
          final message = event['message'];
          final usage = message is Map ? message['usage'] : null;
          if (usage is Map) {
            inputTokens = (usage['input_tokens'] as num?)?.toInt() ?? 0;
            cachedTokens =
                (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
          }
          break;
        case 'content_block_start':
          final index = (event['index'] as num?)?.toInt() ?? 0;
          final block = event['content_block'];
          if (block is Map && block['type'] == 'tool_use') {
            calls[index] = {
              'id': '${block['id'] ?? ''}',
              'name': '${block['name'] ?? ''}',
              'arguments': '',
            };
          }
          break;
        case 'content_block_delta':
          final index = (event['index'] as num?)?.toInt() ?? 0;
          final delta = event['delta'];
          if (delta is Map) {
            if (delta['type'] == 'text_delta') {
              final piece = delta['text'];
              if (piece is String && piece.isNotEmpty) {
                content.write(piece);
                onDelta(piece);
              }
            } else if (delta['type'] == 'input_json_delta' &&
                calls.containsKey(index)) {
              calls[index]!['arguments'] =
                  '${calls[index]!['arguments']}${delta['partial_json'] ?? ''}';
            }
          }
          break;
        case 'message_delta':
          final delta = event['delta'];
          final usage = event['usage'];
          if (delta is Map && delta['stop_reason'] is String) {
            stopReason = delta['stop_reason'] as String;
          }
          if (usage is Map) {
            outputTokens =
                (usage['output_tokens'] as num?)?.toInt() ?? outputTokens;
          }
          break;
        case 'message_stop':
          stopped = true;
          break;
        case 'error':
          throw const PraxoError('MODEL_STREAM', 'anthropic: stream error');
      }
    }
    if (!stopped && stopReason == null) {
      throw const PraxoError(
          'MODEL_STREAM', 'anthropic: stream ended before completion');
    }
    final keys = calls.keys.toList()..sort();
    final toolCalls = <ToolCall>[];
    for (final index in keys) {
      final call = calls[index]!;
      if (call['name']!.isEmpty) continue;
      var arguments = <String, dynamic>{};
      if (call['arguments']!.isNotEmpty) {
        dynamic parsed;
        try {
          parsed = Json.parse(call['arguments']!);
        } on FormatException {
          throw const PraxoError(
              'PROVIDER_JSON', 'anthropic: invalid tool arguments');
        }
        if (parsed is! Map) {
          throw const PraxoError(
              'PROVIDER_JSON', 'anthropic: invalid tool arguments');
        }
        arguments = Map<String, dynamic>.from(parsed);
      }
      toolCalls.add(ToolCall(
        id: call['id']!,
        name: call['name']!,
        arguments: arguments,
      ));
    }
    return Response(
      message: Message.assistant(content.toString(), toolCalls),
      usage: Usage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cachedTokens: cachedTokens,
      ),
      finishReason: stopReason,
    );
  }

  /// Handles buildPayload().
  Map<String, dynamic> buildPayload(Request request) {
    final built = _buildMessages(request.messages);
    final payload = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': built.messages,
    };
    if (built.system.isNotEmpty) payload['system'] = built.system;
    if (request.tools.isNotEmpty) {
      payload['tools'] = request.tools
          .map((tool) => <String, dynamic>{
                'name': tool.name,
                'description': tool.description,
                'input_schema': tool.parameters ??
                    <String, dynamic>{
                      'type': 'object',
                      'properties': <String, dynamic>{},
                    },
              })
          .toList();
      final choice = _toolChoice(request.toolChoice);
      if (choice != null) payload['tool_choice'] = choice;
    }
    if (request.temperature != 0) {
      payload['temperature'] = request.temperature;
    }
    return payload;
  }

  /// Handles parseResponse().
  Response parseResponse(dynamic data) {
    final error = Json.get(data, 'error');
    if (error != null) {
      throw PraxoError('PROVIDER_HTTP',
          'anthropic: ${Json.string(error, 'message') ?? 'error'}');
    }
    final text = StringBuffer();
    final calls = <ToolCall>[];
    for (final block in Json.array(data, 'content')) {
      final type = Json.string(block, 'type');
      if (type == 'text') {
        text.write(Json.string(block, 'text') ?? '');
      } else if (type == 'tool_use') {
        calls.add(ToolCall(
          id: Json.string(block, 'id') ?? '',
          name: Json.string(block, 'name') ?? '',
          arguments: _arguments(Json.get(block, 'input')),
        ));
      }
    }
    final usage = Json.get(data, 'usage') ?? const <String, dynamic>{};
    return Response(
      message: Message(
        role: roleAssistant,
        content: text.toString(),
        toolCalls: calls,
      ),
      usage: Usage(
        inputTokens: Json.integer(usage, 'input_tokens'),
        outputTokens: Json.integer(usage, 'output_tokens'),
        cachedTokens: Json.integer(usage, 'cache_read_input_tokens'),
      ),
      finishReason: Json.string(data, 'stop_reason'),
    );
  }

  void _validate() {
    if (apiKey == null || apiKey!.isEmpty) {
      throw const PraxoError(
          'MODEL_CONFIG', 'anthropic: API key is required');
    }
    if (model.isEmpty) {
      throw const PraxoError('MODEL_CONFIG', 'anthropic: model is required');
    }
  }

  String _root() => baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        if (apiKey != null) 'x-api-key': apiKey!,
        'anthropic-version': version,
      };

  _Messages _buildMessages(List<Message> messages) {
    final system = <String>[];
    final out = <Map<String, dynamic>>[];
    final pending = <Map<String, dynamic>>[];
    void flush() {
      if (pending.isEmpty) return;
      out.add({'role': 'user', 'content': List.of(pending)});
      pending.clear();
    }

    for (final message in messages) {
      if (message.role == roleSystem) {
        if (message.content != null && message.content!.isNotEmpty) {
          system.add(message.content!);
        }
        continue;
      }
      if (message.role == roleTool) {
        pending.add({
          'type': 'tool_result',
          'tool_use_id': message.toolId ?? '',
          'content': message.content ?? '',
        });
        continue;
      }
      flush();
      final content = _messageContent(message);
      if (content.isNotEmpty) {
        out.add({'role': message.role, 'content': content});
      }
    }
    flush();
    return _Messages(system.join('\n\n'), out);
  }

  List<Map<String, dynamic>> _messageContent(Message message) {
    final content = <Map<String, dynamic>>[];
    if (message.content != null && message.content!.isNotEmpty) {
      content.add({'type': 'text', 'text': message.content});
    }
    for (final block in message.contentBlocks) {
      if (block.type == 'text' &&
          block.text != null &&
          block.text!.isNotEmpty) {
        content.add({'type': 'text', 'text': block.text});
      }
    }
    for (final call in message.toolCalls) {
      content.add({
        'type': 'tool_use',
        'id': call.id,
        'name': call.name,
        'input': call.arguments,
      });
    }
    return content;
  }

  Map<String, dynamic>? _toolChoice(String? choice) {
    switch (choice) {
      case 'auto':
        return {'type': 'auto'};
      case 'required':
        return {'type': 'any'};
      case 'none':
        return {'type': 'none'};
      default:
        return null;
    }
  }

  Map<String, dynamic> _arguments(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }
}

class _Messages {
  final String system;
  final List<Map<String, dynamic>> messages;

  const _Messages(this.system, this.messages);
}
