import 'dart:convert';
import 'dart:io';

import '../errors.dart';
import '../json.dart';
import '../models.dart';
import '../runtime.dart';

typedef OtelClock = int Function();

typedef OtelTransport = OtelResponse Function(
    String method, String url, String body, Map<String, String> headers);

class OtelResponse {
  final int status;
  final String body;

  const OtelResponse(this.status, this.body);
}

int _otelDefaultClock() =>
    DateTime.now().toUtc().microsecondsSinceEpoch * 1000;

class OtelSink implements EventSink {
  static const int maxBody = 512;

  final String endpoint;
  final String serviceName;
  final List<String> allowedDataKeys;
  final OtelTransport? transport;
  final OtelClock? clock;

  OtelSink({
    required this.endpoint,
    this.serviceName = 'praxo-core',
    this.allowedDataKeys = const [],
    this.transport,
    this.clock,
  });

  @override
  void emit(Event event) {
    if (endpoint.trim().isEmpty) {
      throw const PraxoError('OTEL_URL', 'otel: endpoint is required');
    }
    final nanos = (clock ?? _otelDefaultClock)();
    final body = Json.stringify(_payload(event, nanos));
    final headers = <String, String>{'content-type': 'application/json'};
    final response = transport != null
        ? transport!('POST', endpoint, body, headers)
        : _post(endpoint, body, headers);
    if (response.status >= 200 && response.status < 300) return;
    final detail =
        response.body.length > maxBody ? response.body.substring(0, maxBody) : response.body;
    throw PraxoError('OTEL_HTTP', 'otel: HTTP ${response.status}: $detail');
  }

  Map<String, dynamic> _payload(Event event, int nanos) {
    final stamp = nanos.toString();
    final data = event.data;
    final key = [
      event.sessionId,
      event.runId ?? '',
      event.type,
      stamp,
      data == null ? '' : Json.stringify(data),
    ].join('|');
    final traceId = _stableId('trace-a:$key') +
        _stableId('trace-b:$key') +
        _stableId('trace-c:$key') +
        _stableId('trace-d:$key');
    final spanId = _stableId('span-a:$key') + _stableId('span-b:$key');
    final attributes = <Map<String, dynamic>>[
      _attribute('praxo.event.type', event.type),
    ];
    if (event.sessionId.isNotEmpty) {
      attributes.add(_attribute('praxo.session.id', event.sessionId));
    }
    final runId = event.runId;
    if (runId != null && runId.isNotEmpty) {
      attributes.add(_attribute('praxo.run.id', runId));
    }
    attributes.add(_attribute('praxo.event.at', stamp));
    if (data is Map) {
      for (final name in allowedDataKeys) {
        if (data.containsKey(name)) {
          attributes.add(_attribute('praxo.event.data.$name', _text(data[name])));
        }
      }
    }
    final span = <String, dynamic>{
      'traceId': traceId,
      'spanId': spanId,
      'name': 'praxo.${event.type}',
      'kind': 1,
      'startTimeUnixNano': stamp,
      'endTimeUnixNano': stamp,
      'attributes': attributes,
    };
    return <String, dynamic>{
      'resourceSpans': [
        {
          'resource': {
            'attributes': [
              _attribute('service.name',
                  serviceName.isEmpty ? 'praxo-core' : serviceName),
            ],
          },
          'scopeSpans': [
            {
              'scope': {'name': 'praxo-core'},
              'spans': [span],
            },
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _attribute(String key, String value) => {
        'key': key,
        'value': {'stringValue': value},
      };

  String _text(dynamic value) {
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return Json.stringify(value);
  }

  String _stableId(String text) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  OtelResponse _post(String endpoint, String body, Map<String, String> headers) {
    final uri = Uri.parse(endpoint);
    if (uri.scheme != 'http') {
      throw const PraxoError('OTEL_HTTP',
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

  OtelResponse _decodeHttp(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final headerEnd = text.indexOf('\r\n\r\n');
    if (headerEnd < 0) {
      throw const PraxoError('OTEL_HTTP', 'otel: invalid HTTP response');
    }
    final lines = text.substring(0, headerEnd).split('\r\n');
    final statusParts = lines.first.split(' ');
    final status =
        statusParts.length > 1 ? int.tryParse(statusParts[1]) ?? 0 : 0;
    return OtelResponse(status, text.substring(headerEnd + 4));
  }
}
