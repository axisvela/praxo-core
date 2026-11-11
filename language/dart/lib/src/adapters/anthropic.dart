import '../errors.dart';
import '../json.dart';
import '../models.dart';
import 'provider_http.dart';

typedef AnthropicSyncTransport = dynamic Function(
    String path, Map<String, dynamic> payload);
typedef AnthropicAsyncTransport = Future<dynamic> Function(
    String path, Map<String, dynamic> payload);

class AnthropicModel {
  final String baseUrl;
  final String model;
  final String? apiKey;
  final String version;
  final int maxTokens;
  final AnthropicSyncTransport? transport;
  final AnthropicAsyncTransport? asyncTransport;
  final Duration timeout;

  AnthropicModel({
    this.baseUrl = 'https://api.anthropic.com',
    required this.model,
    this.apiKey,
    this.version = '2023-06-01',
    this.maxTokens = 1024,
    this.transport,
    this.asyncTransport,
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
