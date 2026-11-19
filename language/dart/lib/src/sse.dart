import 'dart:convert';

import 'errors.dart';
import 'models.dart';

Response parseSseResponse(String text, void Function(String) onDelta) {
  final content = StringBuffer();
  final calls = <int, Map<String, String>>{};
  var inputTokens = 0;
  var outputTokens = 0;
  String? finishReason;
  var done = false;

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith('data:')) continue;
    final chunk = line.substring(5).trim();
    if (chunk.isEmpty) continue;
    if (chunk == '[DONE]') {
      done = true;
      break;
    }

    dynamic event;
    try {
      event = jsonDecode(chunk);
    } on FormatException {
      throw const PraxoError('MODEL_STREAM', 'invalid SSE packet');
    }
    if (event is! Map) continue;

    final usage = event['usage'];
    if (usage is Map) {
      inputTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
      outputTokens = (usage['completion_tokens'] as num?)?.toInt() ?? 0;
    }

    final choices = event['choices'];
    if (choices is! List) continue;
    for (final choice in choices) {
      if (choice is! Map) continue;
      final delta = choice['delta'];
      if (delta is Map) {
        final piece = delta['content'];
        if (piece is String && piece.isNotEmpty) {
          content.write(piece);
          onDelta(piece);
        }
        final toolCalls = delta['tool_calls'];
        if (toolCalls is List) {
          for (final item in toolCalls) {
            if (item is! Map) continue;
            final index = (item['index'] as num?)?.toInt() ?? calls.length;
            final slot = calls.putIfAbsent(
                index, () => <String, String>{'id': '', 'name': '', 'arguments': ''});
            final id = item['id'];
            if (id is String) slot['id'] = '${slot['id']}$id';
            final function = item['function'];
            if (function is Map) {
              final name = function['name'];
              if (name is String) slot['name'] = '${slot['name']}$name';
              final arguments = function['arguments'];
              if (arguments is String) {
                slot['arguments'] = '${slot['arguments']}$arguments';
              }
            }
          }
        }
      }
      final reason = choice['finish_reason'];
      if (reason is String) {
        finishReason = reason;
        done = true;
      }
    }
  }

  if (!done) {
    throw const PraxoError('MODEL_STREAM', 'stream ended before completion');
  }

  final keys = calls.keys.toList()..sort();
  final toolCalls = <ToolCall>[];
  for (final key in keys) {
    final slot = calls[key]!;
    if (slot['name']!.isEmpty) continue;
    var arguments = <String, dynamic>{};
    if (slot['arguments']!.isNotEmpty) {
      dynamic parsed;
      try {
        parsed = jsonDecode(slot['arguments']!);
      } on FormatException {
        throw const PraxoError(
            'PROVIDER_JSON', 'provider returned invalid tool arguments');
      }
      if (parsed is! Map) {
        throw const PraxoError(
            'PROVIDER_JSON', 'provider returned invalid tool arguments');
      }
      arguments = Map<String, dynamic>.from(parsed);
    }
    toolCalls.add(ToolCall(
      id: slot['id']!,
      name: slot['name']!,
      arguments: arguments,
    ));
  }

  return Response(
    message: Message.assistant(content.toString(), toolCalls),
    usage: Usage(inputTokens: inputTokens, outputTokens: outputTokens),
    finishReason: finishReason,
  );
}
