import 'dart:convert';
import 'dart:io';

import '../errors.dart';
import '../json.dart';
import '../models.dart';
import '../runtime.dart';

typedef HarmovelaClock = ({int seconds, int nanos}) Function();

typedef HarmovelaTransport = HarmovelaResponse Function(
    String baseUrl, String path, String body, Map<String, String> headers);

class HarmovelaResponse {
  final int status;
  final String body;

  const HarmovelaResponse(this.status, this.body);
}

({int seconds, int nanos}) _harmovelaDefaultClock() {
  final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
  return (seconds: micros ~/ 1000000, nanos: (micros % 1000000) * 1000);
}

class HarmovelaSink implements EventSink {
  static const int maxBody = 1024;

  final String baseUrl;
  final String source;
  final String specVersion;
  final HarmovelaTransport? transport;
  final HarmovelaClock? clock;

  HarmovelaSink({
    required String baseUrl,
    this.source = 'praxo-core',
    this.specVersion = '0.2',
    this.transport,
    this.clock,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  @override
  void emit(Event event) {
    if (baseUrl.isEmpty) {
      throw const PraxoError('HARMOVELA_URL', 'harmovela: base URL is required');
    }
    final at = (clock ?? _harmovelaDefaultClock)();
    final envelope = <String, dynamic>{
      'spec_version': specVersion.isEmpty ? '0.2' : specVersion,
      'id': _eventId(event, at),
      'type': event.type,
      'source': source.isEmpty ? 'praxo-core' : source,
      'created_at': _createdAt(at),
      'payload': _payload(event),
    };
    final body = Json.stringify(envelope);
    final headers = <String, String>{'content-type': 'application/json'};
    final response = transport != null
        ? transport!(baseUrl, '/events', body, headers)
        : _post(baseUrl, '/events', body, headers);
    if (response.status >= 200 && response.status < 300) return;
    final detail = response.body.length > maxBody
        ? response.body.substring(0, maxBody)
        : response.body;
    throw PraxoError(
        'HARMOVELA_HTTP', 'harmovela: HTTP ${response.status}: $detail');
  }

  Map<String, dynamic> _payload(Event event) {
    final payload = <String, dynamic>{};
    final data = event.data;
    if (data is Map) {
      data.forEach((key, value) => payload[key.toString()] = value);
    }
    if (event.sessionId.isNotEmpty) payload['session_id'] = event.sessionId;
    final runId = event.runId;
    if (runId != null && runId.isNotEmpty) payload['run_id'] = runId;
    return payload;
  }

  String _eventId(Event event, ({int seconds, int nanos}) at) {
    final runId = event.runId;
    final prefix = runId != null && runId.isNotEmpty
        ? runId
        : event.sessionId.isNotEmpty
            ? event.sessionId
            : 'event';
    final stamp = at.seconds * 1000000000 + at.nanos;
    return '$prefix-$stamp';
  }

  String _createdAt(({int seconds, int nanos}) at) {
    final utc =
        DateTime.fromMillisecondsSinceEpoch(at.seconds * 1000, isUtc: true);
    final date = '${_pad(utc.year, 4)}-${_pad(utc.month, 2)}-${_pad(utc.day, 2)}'
        'T${_pad(utc.hour, 2)}:${_pad(utc.minute, 2)}:${_pad(utc.second, 2)}';
    return '$date.${_pad(at.nanos, 9)}Z';
  }

  String _pad(int value, int width) => value.toString().padLeft(width, '0');

  HarmovelaResponse _post(String baseUrl, String path, String body,
      Map<String, String> headers) {
    final uri = Uri.parse('$baseUrl$path');
    if (uri.scheme != 'http') {
      throw const PraxoError('HARMOVELA_HTTP',
          'synchronous sink supports http only; inject a transport for https');
    }
    final bodyBytes = utf8.encode(body);
    final socket = RawSynchronousSocket.connectSync(
        uri.host, uri.port == 0 ? 80 : uri.port);
    try {
      final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      final lines = <String>[
        'POST $target HTTP/1.1',
        'Host: ${uri.host}',
        'content-type: ${headers['content-type']}',
        'Content-Length: ${bodyBytes.length}',
        'Connection: close',
      ];
      socket.writeFromSync(utf8.encode('${lines.join('\r\n')}\r\n\r\n'));
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

  HarmovelaResponse _decodeHttp(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final headerEnd = text.indexOf('\r\n\r\n');
    if (headerEnd < 0) {
      throw const PraxoError(
          'HARMOVELA_HTTP', 'harmovela: invalid HTTP response');
    }
    final lines = text.substring(0, headerEnd).split('\r\n');
    final statusParts = lines.first.split(' ');
    final status =
        statusParts.length > 1 ? int.tryParse(statusParts[1]) ?? 0 : 0;
    var body = text.substring(headerEnd + 4);
    final responseHeaders = <String, String>{};
    for (final line in lines.skip(1)) {
      final index = line.indexOf(':');
      if (index > 0) {
        responseHeaders[line.substring(0, index).toLowerCase()] =
            line.substring(index + 1).trim();
      }
    }
    if ((responseHeaders['transfer-encoding'] ?? '')
        .toLowerCase()
        .contains('chunked')) {
      body = _decodeChunked(body);
    }
    return HarmovelaResponse(status, body);
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
      index = lineEnd + 2;
      final end = index + size;
      if (end > body.length) break;
      output.write(body.substring(index, end));
      index = end + 2;
    }
    return output.toString();
  }
}
