import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors.dart';
import 'mcp.dart';

class McpStreamableHttpTransport implements McpTransport {
  final String endpoint;
  final Map<String, String> headers;
  final String protocolVersion;
  final HttpClient _client;

  String _sessionId = '';
  int _nextId = 0;
  bool _closed = false;

  McpStreamableHttpTransport({
    required this.endpoint,
    this.headers = const {},
    this.protocolVersion = '2025-03-26',
    HttpClient? client,
  }) : _client = client ?? HttpClient() {
    final uri = Uri.parse(endpoint);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const PraxoError('MCP_TRANSPORT', 'mcp: invalid HTTP endpoint');
    }
    if (uri.scheme == 'http' && !_isLoopback(uri.host)) {
      throw const PraxoError(
          'MCP_TRANSPORT', 'mcp: HTTP endpoint must use HTTPS');
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  ) async {
    if (_closed) {
      throw const PraxoError('MCP_CLOSED', 'mcp: client is closed');
    }
    final id = ++_nextId;
    final response = await _post(
      {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      },
      timeout,
    );
    final error = response['error'];
    if (error is Map) {
      throw PraxoError(
          'MCP_RPC', 'mcp: $method failed: ${error['message'] ?? 'JSON-RPC error'}');
    }
    final result = response['result'];
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  @override
  void notify(String method, Map<String, dynamic> params) {
    if (_closed) return;
    unawaited(_post(
      {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      },
      const Duration(seconds: 30),
    ).catchError((Object _) => <String, dynamic>{}));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_sessionId.isNotEmpty) {
      try {
        final request = await _client.deleteUrl(Uri.parse(endpoint));
        _applyHeaders(request);
        await (await request.close()).drain<void>();
      } catch (_) {
        // Session termination is best-effort.
      }
    }
    _client.close(force: true);
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> message,
    Duration timeout,
  ) async {
    final httpRequest = await _client.postUrl(Uri.parse(endpoint));
    _applyHeaders(httpRequest);
    httpRequest.write(jsonEncode(message));
    final response = await httpRequest.close().timeout(timeout);
    final session = response.headers.value('mcp-session-id');
    if (session != null && session.isNotEmpty) {
      _sessionId = session;
    }
    final body = await response.transform(utf8.decoder).join();
    final status = response.statusCode;
    if (status == 202 || status == 204 || body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    if (status < 200 || status >= 300) {
      throw PraxoError(
          'MCP_TRANSPORT', 'mcp: HTTP $status: ${body.substring(0, body.length > 512 ? 512 : body.length)}');
    }
    final contentType = response.headers.contentType?.mimeType ?? '';
    final decoded = contentType.contains('text/event-stream')
        ? _parseSse(body, message['id'] as int?)
        : _parseJson(body);
    final result = decoded['result'];
    if (result is Map && result['protocolVersion'] is String) {
      // The negotiated version is tracked by the client.
    }
    return decoded;
  }

  void _applyHeaders(HttpClientRequest request) {
    request.headers.set('content-type', 'application/json');
    request.headers.set('accept', 'application/json, text/event-stream');
    request.headers.set('mcp-protocol-version', protocolVersion);
    if (_sessionId.isNotEmpty) {
      request.headers.set('mcp-session-id', _sessionId);
    }
    headers.forEach(request.headers.set);
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through.
    }
    throw const PraxoError('MCP_PROTOCOL', 'mcp: server sent invalid JSON');
  }

  Map<String, dynamic> _parseSse(String body, int? id) {
    final messages = <Map<String, dynamic>>[];
    final data = <String>[];
    for (final raw in body.split(RegExp(r'\r\n|\n|\r'))) {
      final line = raw;
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          messages.add(_decode(data.join('\n')));
          data.clear();
        }
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('data:')) {
        data.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
      }
    }
    if (data.isNotEmpty) {
      messages.add(_decode(data.join('\n')));
    }
    for (final message in messages) {
      if (id != null && message['id'] == id) return message;
    }
    if (messages.isEmpty) {
      throw const PraxoError(
          'MCP_PROTOCOL', 'mcp: response contained no message');
    }
    return messages.first;
  }

  Map<String, dynamic> _decode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through.
    }
    throw const PraxoError(
        'MCP_PROTOCOL', 'mcp: server sent invalid SSE JSON');
  }

  static bool _isLoopback(String host) {
    final value = host.toLowerCase();
    return value == 'localhost' ||
        value == '127.0.0.1' ||
        value == '::1' ||
        value.startsWith('127.');
  }
}
