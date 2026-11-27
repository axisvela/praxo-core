import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The pluginProtocolVersion value.
const pluginProtocolVersion = 1;
/// The pluginControlService value.
const pluginControlService = 'host.control';
/// The pluginHealthMethod value.
const pluginHealthMethod = 'health';
/// The pluginShutdownMethod value.
const pluginShutdownMethod = 'shutdown';
/// The pluginCancelMethod value.
const pluginCancelMethod = 'cancel';
/// The pluginDefaultTokenEnv value.
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

/// The PluginCallException API.
class PluginCallException implements Exception {
  /// The code value.
  final String code;
  /// The message value.
  final String message;

  /// Creates a PluginCallException instance.
  PluginCallException(String code, [String message = ''])
      : code = _callCodes.contains(code) ? code : 'INTERNAL',
        message = message.isEmpty ? code : message;

  @override
  String toString() => '$code: $message';
}

/// The PluginProcessConfig API.
class PluginProcessConfig {
  /// The pluginId value.
  final String pluginId;
  /// The path value.
  final String path;
  /// The args value.
  final List<String> args;
  /// The dir value.
  final String? dir;
  /// The String value.
  final Map<String, String>? env;
  /// The token value.
  final String token;
  /// The tokenEnvVar value.
  final String tokenEnvVar;
  /// The startTimeout value.
  final Duration startTimeout;
  /// The invokeTimeout value.
  final Duration invokeTimeout;
  /// The gracePeriod value.
  final Duration gracePeriod;
  /// The maxFrameBytes value.
  final int maxFrameBytes;

  /// Creates a PluginProcessConfig instance.
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

/// The PluginProcessHost API.
class PluginProcessHost {
  /// The config value.
  final PluginProcessConfig config;
  final String _token;
  Process? _process;
  StreamIterator<String>? _lines;
  final StringBuffer _stderr = StringBuffer();
  int _sequence = 0;
  bool _active = false;

  /// Creates a PluginProcessHost instance.
  PluginProcessHost(this.config)
      : _token = config.token.isNotEmpty ? config.token : _randomToken() {
    if (config.pluginId.isEmpty) {
      throw StateError('plugin: PluginID is required');
    }
    if (config.path.isEmpty) {
      throw StateError('plugin: path is required');
    }
  }

  /// Returns the pluginId value.
  String get pluginId => config.pluginId;

  /// Returns the isActive value.
  bool get isActive => _active;

  /// Returns the stderrText value.
  String get stderrText => _stderr.toString();

  /// Handles start().
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

  /// Handles invoke().
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

  /// Handles stop().
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
