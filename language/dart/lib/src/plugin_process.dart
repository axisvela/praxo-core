import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const pluginProtocolVersion = 1;
const pluginControlService = 'host.control';
const pluginHealthMethod = 'health';
const pluginShutdownMethod = 'shutdown';
const pluginCancelMethod = 'cancel';
const pluginDefaultTokenEnv = 'PRAXOVELA_PLUGIN_TOKEN';

const _callCodes = {
  'CAPABILITY_DENIED',
  'NOT_ACTIVE',
  'NOT_FOUND',
  'INVALID_REQUEST',
  'TIMEOUT',
  'INTERNAL',
  'CANCELED',
};

class PluginCallException implements Exception {
  final String code;
  final String message;

  PluginCallException(String code, [String message = ''])
      : code = _callCodes.contains(code) ? code : 'INTERNAL',
        message = message.isEmpty ? code : message;

  @override
  String toString() => '$code: $message';
}

class PluginProcessConfig {
  final String pluginId;
  final String path;
  final List<String> args;
  final String? dir;
  final Map<String, String>? env;
  final String token;
  final String tokenEnvVar;
  final Duration startTimeout;
  final Duration invokeTimeout;
  final Duration gracePeriod;
  final int maxFrameBytes;

  const PluginProcessConfig({
    required this.pluginId,
    required this.path,
    this.args = const [],
    this.dir,
    this.env,
    this.token = '',
    this.tokenEnvVar = pluginDefaultTokenEnv,
    this.startTimeout = const Duration(seconds: 10),
    this.invokeTimeout = const Duration(seconds: 30),
    this.gracePeriod = const Duration(seconds: 5),
    this.maxFrameBytes = 8 << 20,
  });
}

class PluginProcessHost {
  final PluginProcessConfig config;
  final String _token;
  Process? _process;
  StreamIterator<String>? _lines;
  final StringBuffer _stderr = StringBuffer();
  int _sequence = 0;
  bool _active = false;

  PluginProcessHost(this.config)
      : _token = config.token.isNotEmpty ? config.token : _randomToken() {
    if (config.pluginId.isEmpty) {
      throw StateError('plugin: PluginID is required');
    }
    if (config.path.isEmpty) {
      throw StateError('plugin: path is required');
    }
  }

  String get pluginId => config.pluginId;

  bool get isActive => _active;

  String get stderrText => _stderr.toString();

  Future<void> start() async {
    if (_process != null) {
      throw StateError('plugin: host already started');
    }
    final environment = <String, String>{
      ...(config.env ?? Platform.environment),
      config.tokenEnvVar: _token,
    };
    final process = await Process.start(
      config.path,
      config.args,
      workingDirectory: config.dir,
      environment: environment,
    );
    _process = process;
    _lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    process.stderr
        .transform(utf8.decoder)
        .listen(_captureStderr, onError: (_) {});
    try {
      await _call(
        pluginControlService,
        pluginHealthMethod,
        <int>[],
        config.startTimeout,
      );
    } catch (_) {
      _terminate();
      rethrow;
    }
    _active = true;
  }

  Future<List<int>> invoke(
    String service,
    String method, [
    List<int> payload = const [],
    Duration? timeout,
  ]) {
    if (!_active) {
      throw PluginCallException('NOT_ACTIVE', 'plugin: host is not active');
    }
    return _call(service, method, payload, timeout ?? config.invokeTimeout);
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    try {
      if (_active) {
        await _call(
          pluginControlService,
          pluginShutdownMethod,
          <int>[],
          config.gracePeriod,
        );
      }
    } catch (_) {
      // best effort
    }
    _active = false;
    try {
      await process.exitCode.timeout(config.gracePeriod);
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(config.gracePeriod);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
    }
    await _lines?.cancel();
    _process = null;
    _lines = null;
  }

  Future<List<int>> _call(
    String service,
    String method,
    List<int> payload,
    Duration timeout,
  ) async {
    final process = _process;
    final lines = _lines;
    if (process == null || lines == null) {
      throw PluginCallException('INTERNAL', 'plugin: process is closed');
    }
    final id = 'req-${++_sequence}';
    final frame = <String, dynamic>{
      'id': id,
      'version': pluginProtocolVersion,
      'plugin_id': config.pluginId,
      'service': service,
      'method': method,
      'token': _token,
      'payload': base64Encode(payload),
    };
    final encoded = '${jsonEncode(frame)}\n';
    if (utf8.encode(encoded).length > config.maxFrameBytes) {
      throw PluginCallException(
          'INVALID_REQUEST', 'plugin: request frame too large');
    }
    process.stdin.write(encoded);
    await process.stdin.flush();
    while (true) {
      final hasLine = await lines.moveNext().timeout(
        timeout,
        onTimeout: () {
          _sendCancel(id);
          _terminate();
          throw PluginCallException(
              'TIMEOUT', 'plugin: invocation timed out');
        },
      );
      if (!hasLine) {
        final detail = stderrText;
        _terminate();
        throw PluginCallException(
            'INTERNAL', detail.isEmpty ? 'plugin: process exited' : detail);
      }
      final Map<String, dynamic> response;
      try {
        final decoded = jsonDecode(lines.current);
        if (decoded is! Map<String, dynamic>) continue;
        response = decoded;
      } on FormatException {
        continue;
      }
      if (response['id'] != id) continue;
      if (response['ok'] != true) {
        throw PluginCallException(
          response['code'] is String ? response['code'] as String : 'INTERNAL',
          response['message'] is String ? response['message'] as String : '',
        );
      }
      final payloadText =
          response['payload'] is String ? response['payload'] as String : '';
      try {
        return base64Decode(payloadText);
      } on FormatException {
        throw PluginCallException('INTERNAL', 'plugin: invalid payload');
      }
    }
  }

  void _sendCancel(String id) {
    final process = _process;
    if (process == null) return;
    final frame = <String, dynamic>{
      'id': id,
      'version': pluginProtocolVersion,
      'plugin_id': config.pluginId,
      'service': pluginControlService,
      'method': pluginCancelMethod,
      'token': _token,
    };
    try {
      process.stdin.write('${jsonEncode(frame)}\n');
    } catch (_) {
      // best effort
    }
  }

  void _captureStderr(String chunk) {
    if (_stderr.length >= 16 << 10) return;
    final remaining = (16 << 10) - _stderr.length;
    _stderr.write(chunk.length <= remaining ? chunk : chunk.substring(0, remaining));
  }

  void _terminate() {
    _active = false;
    _lines?.cancel();
    _process?.kill(ProcessSignal.sigkill);
    _process = null;
    _lines = null;
  }

  static String _randomToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
