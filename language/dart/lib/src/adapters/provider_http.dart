import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors.dart';
import '../json.dart';

dynamic postSync({
  required Uri uri,
  required Map<String, dynamic> payload,
  required Map<String, String> headers,
  required Duration timeout,
}) {
  if (uri.scheme != 'http') {
    throw const PraxoError('PROVIDER_HTTP',
        'synchronous transport supports http only; use generateAsync or inject a transport for https');
  }
  final bodyBytes = utf8.encode(Json.stringify(payload));
  final socket = RawSynchronousSocket.connectSync(
      uri.host, uri.port == 0 ? 80 : uri.port);
  try {
    final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final lines = <String>[
      'POST $target HTTP/1.1',
      'Host: ${uri.host}',
      'Content-Type: application/json',
      'Accept: application/json',
      'Content-Length: ${bodyBytes.length}',
      'Connection: close',
      ...headers.entries.map((entry) => '${entry.key}: ${entry.value}'),
    ];
    socket.writeFromSync(utf8.encode('${lines.join('\r\n')}\r\n\r\n'));
    socket.writeFromSync(bodyBytes);
    final bytes = <int>[];
    while (true) {
      final chunk = socket.readSync(65536);
      if (chunk == null || chunk.isEmpty) break;
      bytes.addAll(chunk);
    }
    return _decode(bytes);
  } finally {
    socket.closeSync();
  }
}

Future<dynamic> postAsync({
  required Uri uri,
  required Map<String, dynamic> payload,
  required Map<String, String> headers,
  required Duration timeout,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.write(Json.stringify(payload));
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    return decodeHttpResponse(response.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

dynamic decodeHttpResponse(int status, String body) {
  if (status < 200 || status >= 300) {
    throw PraxoError(
        'PROVIDER_HTTP', 'provider returned HTTP $status: ${bounded(body)}');
  }
  try {
    return Json.parse(body);
  } on FormatException {
    throw const PraxoError(
        'PROVIDER_RESPONSE', 'provider returned invalid JSON');
  }
}

String bounded(String value) =>
    value.length <= 512 ? value : value.substring(0, 512);

dynamic _decode(List<int> bytes) {
  final text = utf8.decode(bytes);
  final split = text.indexOf('\r\n\r\n');
  if (split < 0) {
    throw const PraxoError(
        'PROVIDER_RESPONSE', 'provider returned an invalid HTTP response');
  }
  final head = text.substring(0, split).split('\r\n');
  final statusParts = head.isEmpty ? <String>[] : head.first.split(' ');
  final status =
      statusParts.length > 1 ? int.tryParse(statusParts[1]) ?? 0 : 0;
  var body = text.substring(split + 4);
  if (head.any((line) => line.toLowerCase() == 'transfer-encoding: chunked')) {
    body = _dechunk(body);
  }
  return decodeHttpResponse(status, body);
}

String _dechunk(String value) {
  final out = StringBuffer();
  var index = 0;
  while (index < value.length) {
    final lineEnd = value.indexOf('\r\n', index);
    if (lineEnd < 0) break;
    final size = int.tryParse(
            value.substring(index, lineEnd).split(';').first.trim(),
            radix: 16) ??
        0;
    index = lineEnd + 2;
    if (size == 0) break;
    out.write(value.substring(index, index + size));
    index += size + 2;
  }
  return out.toString();
}
