import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../agent.dart';
import '../errors.dart';
import '../json.dart';
import '../models.dart';

typedef OpenAISyncTransport = dynamic Function(
    String path, Map<String, dynamic> payload);
typedef OpenAIAsyncTransport = Future<dynamic> Function(
    String path, Map<String, dynamic> payload);

class OpenAICompatibleModel implements Model {
  final String baseUrl;
  final String model;
  final String? apiKey;
  final OpenAISyncTransport? transport;
  final OpenAIAsyncTransport? asyncTransport;
  final Duration timeout;

  OpenAICompatibleModel({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    this.transport,
    this.asyncTransport,
    this.timeout = const Duration(seconds: 60),
  });

  @override
  Response generate(Request request) {
    _requireBaseUrl();
    final payload = buildPayload(request);
    final data = transport != null
        ? transport!('/chat/completions', payload)
        : _postSync('/chat/completions', payload);
    return parseResponse(data);
  }

  Future<Response> generateAsync(Request request) async {
    _requireBaseUrl();
    final payload = buildPayload(request);
    final data = asyncTransport != null
        ? await asyncTransport!('/chat/completions', payload)
        : await _postAsync('/chat/completions', payload);
    return parseResponse(data);
  }

  Map<String, dynamic> buildPayload(Request request) {
    final messages =
        request.messages.map((message) => _messagePayload(message)).toList();
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
    };
    if (request.tools.isNotEmpty) {
      payload['tools'] = request.tools
          .map((tool) => <String, dynamic>{
                'type': 'function',
                'function': <String, dynamic>{
                  'name': tool.name,
                  'description': tool.description,
                  'parameters':
                      tool.parameters ?? <String, dynamic>{'type': 'object'},
                },
              })
          .toList();
    }
    if (request.toolChoice != null) {
      payload['tool_choice'] = request.toolChoice;
    }
    if (request.responseFormat != null) {
      payload['response_format'] = request.responseFormat;
    }
    if (request.temperature != 0) {
      payload['temperature'] = request.temperature;
    }
    return payload;
  }

  Response parseResponse(dynamic data) {
    final choices = Json.array(data, 'choices');
    if (choices.isEmpty) {
      throw const PraxoError(
          'PROVIDER_RESPONSE', 'provider response has no choices');
    }
    final choice = choices.first;
    final message = Json.get(choice, 'message') ?? const <String, dynamic>{};
    final calls = <ToolCall>[];
    for (final item in Json.array(message, 'tool_calls')) {
      final function = Json.get(item, 'function') ?? const <String, dynamic>{};
      calls.add(ToolCall(
        id: Json.string(item, 'id') ?? '',
        name: Json.string(function, 'name') ?? '',
        arguments: _arguments(Json.get(function, 'arguments')),
      ));
    }
    final usage = Json.get(data, 'usage') ?? const <String, dynamic>{};
    return Response(
      message: Message(
        role: roleAssistant,
        content: Json.string(message, 'content'),
        toolCalls: calls,
      ),
      usage: Usage(
        inputTokens: Json.integer(usage, 'prompt_tokens'),
        outputTokens: Json.integer(usage, 'completion_tokens'),
      ),
      finishReason: Json.string(choice, 'finish_reason'),
    );
  }

  static dynamic decodeHttpResponse(int status, String body) {
    if (status < 200 || status >= 300) {
      throw PraxoError(
          'PROVIDER_HTTP', 'provider returned HTTP $status: ${_bounded(body)}');
    }
    try {
      return Json.parse(body);
    } on FormatException {
      throw const PraxoError(
          'PROVIDER_RESPONSE', 'provider returned invalid JSON');
    }
  }

  Map<String, dynamic> _messagePayload(Message message) {
    var content = message.content;
    if ((content == null || content.isEmpty) &&
        message.contentBlocks.isNotEmpty) {
      content = message.contentBlocks
          .where((block) => block.type == 'text' && block.text != null)
          .map((block) => block.text!)
          .join();
    }
    final out = <String, dynamic>{'role': message.role};
    if (content != null) {
      out['content'] = content;
    }
    if (message.role == roleAssistant && message.toolCalls.isNotEmpty) {
      out['tool_calls'] = message.toolCalls
          .map((call) => <String, dynamic>{
                'id': call.id,
                'type': 'function',
                'function': <String, dynamic>{
                  'name': call.name,
                  'arguments': Json.stringify(call.arguments),
                },
              })
          .toList();
    }
    if (message.role == roleTool && message.toolId != null) {
      out['tool_call_id'] = message.toolId;
    }
    return out;
  }

  Map<String, dynamic> _arguments(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = Json.parse(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        throw const PraxoError(
            'PROVIDER_RESPONSE', 'tool arguments are not valid JSON');
      }
      throw const PraxoError(
          'PROVIDER_RESPONSE', 'tool arguments must be an object');
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  void _requireBaseUrl() {
    if (baseUrl.trim().isEmpty) {
      throw const PraxoError('PROVIDER_HTTP', 'provider base URL is required');
    }
  }

  String _endpoint(String path) {
    final trimmed = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$trimmed$path';
  }

  dynamic _postSync(String path, Map<String, dynamic> payload) {
    final uri = Uri.parse(_endpoint(path));
    if (uri.scheme != 'http') {
      throw const PraxoError('PROVIDER_HTTP',
          'synchronous transport supports http only; use generateAsync or inject a transport for https');
    }
    final bodyBytes = utf8.encode(Json.stringify(payload));
    final socket = RawSynchronousSocket.connectSync(
        uri.host, uri.port == 0 ? 80 : uri.port);
    try {
      final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      final headers = <String>[
        'POST $target HTTP/1.1',
        'Host: ${uri.host}',
        'Content-Type: application/json',
        'Accept: application/json',
        'Content-Length: ${bodyBytes.length}',
        'Connection: close',
        if (apiKey != null) 'Authorization: Bearer $apiKey',
      ];
      socket.writeFromSync(utf8.encode('${headers.join('\r\n')}\r\n\r\n'));
      socket.writeFromSync(bodyBytes);
      final bytes = <int>[];
      while (true) {
        final chunk = socket.readSync(65536);
        if (chunk == null || chunk.isEmpty) break;
        bytes.addAll(chunk);
      }
      return _decodeHttp(bytes);
    } finally {
      socket.closeSync();
    }
  }

  Future<dynamic> _postAsync(String path, Map<String, dynamic> payload) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(Uri.parse(_endpoint(path)));
      request.headers.contentType = ContentType.json;
      request.headers.set('Accept', 'application/json');
      if (apiKey != null) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      request.write(Json.stringify(payload));
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      return decodeHttpResponse(response.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  dynamic _decodeHttp(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final headerEnd = text.indexOf('\r\n\r\n');
    if (headerEnd < 0) {
      throw const PraxoError(
          'PROVIDER_HTTP', 'provider returned an invalid HTTP response');
    }
    final lines = text.substring(0, headerEnd).split('\r\n');
    final statusParts = lines.first.split(' ');
    final status =
        statusParts.length > 1 ? int.tryParse(statusParts[1]) ?? 0 : 0;
    var body = text.substring(headerEnd + 4);
    final headers = <String, String>{};
    for (final line in lines.skip(1)) {
      final index = line.indexOf(':');
      if (index > 0) {
        headers[line.substring(0, index).toLowerCase()] =
            line.substring(index + 1).trim();
      }
    }
    if ((headers['transfer-encoding'] ?? '')
        .toLowerCase()
        .contains('chunked')) {
      body = _decodeChunked(body);
    }
    return decodeHttpResponse(status, body);
  }

  String _decodeChunked(String body) {
    final output = StringBuffer();
    var index = 0;
    while (index < body.length) {
      final lineEnd = body.indexOf('\r\n', index);
      if (lineEnd < 0) break;
      final size = int.tryParse(
              body.substring(index, lineEnd).split(';').first.trim(),
              radix: 16) ??
          0;
      if (size == 0) break;
      final start = lineEnd + 2;
      output.write(body.substring(start, start + size));
      index = start + size + 2;
    }
    return output.toString();
  }

  static String _bounded(String body) =>
      body.length > 512 ? body.substring(0, 512) : body;
}
