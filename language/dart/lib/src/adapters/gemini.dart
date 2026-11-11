import '../errors.dart';
import '../json.dart';
import '../models.dart';
import 'provider_http.dart';

typedef GeminiSyncTransport = dynamic Function(
    String path, Map<String, dynamic> payload);
typedef GeminiAsyncTransport = Future<dynamic> Function(
    String path, Map<String, dynamic> payload);

class GeminiModel {
  final String baseUrl;
  final String model;
  final String? apiKey;
  final int maxOutputTokens;
  final GeminiSyncTransport? transport;
  final GeminiAsyncTransport? asyncTransport;
  final Duration timeout;

  GeminiModel({
    this.baseUrl = 'https://generativelanguage.googleapis.com',
    required this.model,
    this.apiKey,
    this.maxOutputTokens = 0,
    this.transport,
    this.asyncTransport,
    this.timeout = const Duration(seconds: 60),
  });

  Response generate(Request request) {
    _validate();
    final payload = buildPayload(request);
    final path = _path();
    final data = transport != null
        ? transport!(path, payload)
        : postSync(
            uri: Uri.parse('${_root()}$path'),
            payload: payload,
            headers: _headers(),
            timeout: timeout,
          );
    return parseResponse(data);
  }

  Future<Response> generateAsync(Request request) async {
    _validate();
    final payload = buildPayload(request);
    final path = _path();
    final data = asyncTransport != null
        ? await asyncTransport!(path, payload)
        : await postAsync(
            uri: Uri.parse('${_root()}$path'),
            payload: payload,
            headers: _headers(),
            timeout: timeout,
          );
    return parseResponse(data);
  }

  Map<String, dynamic> buildPayload(Request request) {
    final built = _buildContents(request.messages);
    final payload = <String, dynamic>{'contents': built.contents};
    if (built.system.isNotEmpty) {
      payload['system_instruction'] = {'parts': built.system};
    }
    if (request.tools.isNotEmpty) {
      payload['tools'] = [
        {
          'functionDeclarations': request.tools
              .map((tool) => <String, dynamic>{
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters ??
                        <String, dynamic>{
                          'type': 'object',
                          'properties': <String, dynamic>{},
                        },
                  })
              .toList(),
        }
      ];
      payload['toolConfig'] = {
        'functionCallingConfig': {'mode': _toolMode(request.toolChoice)},
      };
    }
    if (request.temperature != 0 || maxOutputTokens > 0) {
      payload['generationConfig'] = {
        'temperature': request.temperature,
        'maxOutputTokens': maxOutputTokens,
      };
    }
    return payload;
  }

  Response parseResponse(dynamic data) {
    final error = Json.get(data, 'error');
    if (error != null) {
      throw PraxoError('PROVIDER_HTTP',
          'gemini: ${Json.string(error, 'message') ?? 'error'}');
    }
    final candidates = Json.array(data, 'candidates');
    if (candidates.isEmpty) {
      throw const PraxoError('PROVIDER_HTTP', 'gemini: empty response');
    }
    final candidate = candidates.first;
    final text = StringBuffer();
    final calls = <ToolCall>[];
    final content = Json.get(candidate, 'content') ?? const <String, dynamic>{};
    for (final part in Json.array(content, 'parts')) {
      final value = Json.string(part, 'text');
      if (value != null) text.write(value);
      final call = Json.get(part, 'functionCall');
      if (call != null) {
        calls.add(ToolCall(
          id: 'call-${calls.length + 1}',
          name: Json.string(call, 'name') ?? '',
          arguments: _arguments(Json.get(call, 'args')),
        ));
      }
    }
    final usage = Json.get(data, 'usageMetadata') ?? const <String, dynamic>{};
    return Response(
      message: Message(
        role: roleAssistant,
        content: text.toString(),
        toolCalls: calls,
      ),
      usage: Usage(
        inputTokens: Json.integer(usage, 'promptTokenCount'),
        outputTokens: Json.integer(usage, 'candidatesTokenCount'),
        cachedTokens: Json.integer(usage, 'cachedContentTokenCount'),
      ),
      finishReason: Json.string(candidate, 'finishReason'),
    );
  }

  void _validate() {
    if (apiKey == null || apiKey!.isEmpty) {
      throw const PraxoError('MODEL_CONFIG', 'gemini: API key is required');
    }
    if (model.isEmpty) {
      throw const PraxoError('MODEL_CONFIG', 'gemini: model is required');
    }
  }

  String _root() => baseUrl.replaceFirst(RegExp(r'/+$'), '');

  String _path() =>
      '/v1beta/models/${Uri.encodeComponent(model)}:generateContent';

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        if (apiKey != null) 'x-goog-api-key': apiKey!,
      };

  _Contents _buildContents(List<Message> messages) {
    final system = <Map<String, dynamic>>[];
    final contents = <Map<String, dynamic>>[];
    final pending = <Map<String, dynamic>>[];
    final names = <String, String>{};
    void flush() {
      if (pending.isEmpty) return;
      contents.add({'role': 'user', 'parts': List.of(pending)});
      pending.clear();
    }

    for (final message in messages) {
      if (message.role == roleSystem) {
        if (message.content != null && message.content!.isNotEmpty) {
          system.add({'text': message.content});
        }
        continue;
      }
      if (message.role == roleTool) {
        final name = names[message.toolId ?? ''] ?? message.toolId ?? 'tool';
        pending.add({
          'functionResponse': {
            'name': name,
            'response': {'result': message.content ?? ''},
          },
        });
        continue;
      }
      flush();
      final parts = _messageParts(message);
      if (parts.isNotEmpty) {
        contents.add({
          'role': message.role == roleAssistant ? 'model' : 'user',
          'parts': parts,
        });
      }
      for (final call in message.toolCalls) {
        if (call.id.isNotEmpty && call.name.isNotEmpty) {
          names[call.id] = call.name;
        }
      }
    }
    flush();
    return _Contents(system, contents);
  }

  List<Map<String, dynamic>> _messageParts(Message message) {
    final parts = <Map<String, dynamic>>[];
    if (message.content != null && message.content!.isNotEmpty) {
      parts.add({'text': message.content});
    }
    for (final block in message.contentBlocks) {
      if (block.type == 'text' &&
          block.text != null &&
          block.text!.isNotEmpty) {
        parts.add({'text': block.text});
      }
    }
    for (final call in message.toolCalls) {
      parts.add({
        'functionCall': {'name': call.name, 'args': call.arguments},
      });
    }
    return parts;
  }

  String _toolMode(String? choice) {
    if (choice == 'required') return 'ANY';
    if (choice == 'none') return 'NONE';
    return 'AUTO';
  }

  Map<String, dynamic> _arguments(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }
}

class _Contents {
  final List<Map<String, dynamic>> system;
  final List<Map<String, dynamic>> contents;

  const _Contents(this.system, this.contents);
}
