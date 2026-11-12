import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors.dart';

abstract class McpTransport {
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  );

  void notify(String method, Map<String, dynamic> params);

  Future<void> close();
}

class McpClient {
  static const defaultProtocolVersion = '2024-11-05';

  final McpTransport transport;
  final String clientVersion;
  final Duration timeout;
  String protocolVersion = '';
  Map<String, dynamic> serverInfo = {};

  bool _connected = false;
  bool _closed = false;

  final String requestedProtocolVersion;

  McpClient({
    required this.transport,
    this.clientVersion = '0.2.0',
    this.timeout = const Duration(seconds: 5),
    this.requestedProtocolVersion = defaultProtocolVersion,
  });

  Future<McpClient> start() async {
    if (_connected) return this;
    final result = await transport.request(
      'initialize',
      {
        'protocolVersion': requestedProtocolVersion,
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'praxo-core', 'version': clientVersion},
      },
      timeout,
    );
    final version = result['protocolVersion'];
    if (version is! String || version.isEmpty) {
      throw const PraxoError(
          'MCP_HANDSHAKE', 'mcp: initialize returned no protocol version');
    }
    protocolVersion = version;
    serverInfo = result['serverInfo'] is Map
        ? Map<String, dynamic>.from(result['serverInfo'] as Map)
        : {};
    transport.notify('notifications/initialized', {});
    _connected = true;
    return this;
  }

  Future<List<Map<String, dynamic>>> listTools() async {
    await _ensureConnected();
    final tools = <Map<String, dynamic>>[];
    final names = <String>{};
    final seen = <String>{};
    String? cursor;
    do {
      final result = await transport.request(
        'tools/list',
        cursor == null ? {} : {'cursor': cursor},
        timeout,
      );
      final list = (result['tools'] as List?) ?? const [];
      for (final item in list) {
        final tool = Map<String, dynamic>.from(item as Map);
        final name = (tool['name'] ?? '').toString();
        if (!names.add(name)) {
          throw PraxoError(
              'MCP_DUPLICATE_TOOL', 'mcp: duplicate tool $name');
        }
        tools.add(tool);
      }
      cursor = result['nextCursor']?.toString();
      if (cursor != null && cursor.isNotEmpty) {
        if (!seen.add(cursor)) {
          throw const PraxoError('MCP_PAGINATION', 'mcp: repeated cursor');
        }
      } else {
        cursor = null;
      }
    } while (cursor != null);
    return tools;
  }

  Future<dynamic> callTool(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    await _ensureConnected();
    final result = await transport.request(
      'tools/call',
      {'name': name, 'arguments': arguments},
      timeout,
    );
    if (result['isError'] == true) {
      throw PraxoError('MCP_TOOL_ERROR', 'mcp: tool $name failed');
    }
    if (result.containsKey('structuredContent')) {
      return result['structuredContent'];
    }
    final texts = <String>[];
    for (final item in (result['content'] as List?) ?? const []) {
      final part = item as Map;
      if (part['type'] == 'text') texts.add((part['text'] ?? '').toString());
    }
    if (texts.isEmpty) return null;
    return texts.length == 1 ? texts.first : texts;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    await transport.close();
  }

  Future<void> _ensureConnected() async {
    if (_closed) {
      throw const PraxoError('MCP_CLOSED', 'mcp: client is closed');
    }
    if (!_connected) await start();
  }
}

class StdioMcpTransport implements McpTransport {
  final String command;
  final List<String> args;
  final Map<String, String>? environment;

  Process? _process;
  StreamSubscription<String>? _subscription;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;
  bool _closed = false;

  StdioMcpTransport(
    this.command, {
    this.args = const [],
    this.environment,
  });

  Future<void> start() async {
    if (_process != null) return;
    final process = await Process.start(command, args, environment: environment);
    _process = process;
    _subscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine);
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  ) async {
    await start();
    if (_closed) {
      throw const PraxoError('MCP_CLOSED', 'mcp: client is closed');
    }
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _write({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      notify('notifications/cancelled', {'requestId': id, 'reason': 'timeout'});
      throw PraxoError('MCP_TIMEOUT', 'mcp: $method timed out');
    }
  }

  @override
  void notify(String method, Map<String, dynamic> params) {
    if (_closed) return;
    _write({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _process?.kill();
    _process = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
            const PraxoError('MCP_CLOSED', 'mcp: client closed'));
      }
    }
    _pending.clear();
  }

  void _write(Map<String, dynamic> message) {
    final stdin = _process?.stdin;
    if (stdin == null) {
      throw const PraxoError('MCP_CLOSED', 'mcp: client is closed');
    }
    stdin.writeln(jsonEncode(message));
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    final error = message['error'];
    if (error is Map) {
      completer.completeError(PraxoError(
          'MCP_RPC', 'mcp: ${error['message'] ?? 'rpc error'}'));
      return;
    }
    final result = message['result'];
    completer.complete(
      result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{},
    );
  }
}
