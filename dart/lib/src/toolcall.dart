import 'json.dart';

class ParsedToolCall {
  String callId;
  final String name;
  final Map<String, dynamic> input;
  final String operation;
  final String resource;
  final String risk;
  final String reason;
  final String idempotencyKey;

  ParsedToolCall({
    this.callId = '',
    required this.name,
    this.input = const {},
    this.operation = '',
    this.resource = '',
    this.risk = '',
    this.reason = '',
    this.idempotencyKey = '',
  });
}

class ToolCallParser {
  static ParsedToolCall? parse(String content) {
    final call = _parseJson(content) ??
        _parseXml(content) ??
        _parseTag(content) ??
        _parsePlain(content);
    if (call == null) return null;
    call.callId = 'tc-${DateTime.now().millisecondsSinceEpoch}';
    return call;
  }

  static String stripMarkup(String content) {
    var output = content;
    output = output.replaceAll(
      RegExp(r'<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)', dotAll: true),
      '',
    );
    output = output.replaceAll(
      RegExp(r'<tool_call_invoke>.*?(?:</tool_call_invoke>|$)', dotAll: true),
      '',
    );
    output = output.replaceAll(
      RegExp(
        r'<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)',
        dotAll: true,
      ),
      '',
    );
    output = output.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return output.trim();
  }

  static Map<String, dynamic>? parseInputJson(String raw) {
    try {
      final value = Json.parse(raw.trim());
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    final escaped = raw.replaceAll('\\', '\\\\');
    try {
      final value = Json.parse(escaped.trim());
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return null;
  }

  static ParsedToolCall? _parseJson(String content) {
    try {
      final value = Json.parse(content);
      if (value is! Map || value['name'] is! String || (value['name'] as String).isEmpty) {
        return null;
      }
      return ParsedToolCall(
        name: value['name'] as String,
        input: value['input'] is Map<String, dynamic>
            ? value['input'] as Map<String, dynamic>
            : const {},
        operation: value['operation'] as String? ?? '',
        resource: value['resource'] as String? ?? '',
        risk: value['risk'] as String? ?? '',
        reason: value['reason'] as String? ?? '',
        idempotencyKey: value['idempotency_key'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static ParsedToolCall? _parseXml(String content) {
    final matches = RegExp(
      r'<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>',
      dotAll: true,
    ).allMatches(content).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    final input = parseInputJson(match.group(2)!);
    if (input == null) return null;
    return ParsedToolCall(name: match.group(1)!, input: input);
  }

  static ParsedToolCall? _parseTag(String content) {
    final matches = RegExp(
      r'<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)',
      dotAll: true,
    ).allMatches(content).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    final input = parseInputJson(match.group(2)!);
    if (input == null) return null;
    return ParsedToolCall(name: match.group(1)!, input: input);
  }

  static ParsedToolCall? _parsePlain(String content) {
    final matches = RegExp(
      r'(?:^|\n)\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*(?:\n|$)',
      dotAll: true,
    ).allMatches(content).toList();
    if (matches.isEmpty) return null;
    final match = matches.last;
    final name = match.group(1)!;
    if (!name.contains('.')) return null;
    final input = parseInputJson(match.group(2)!);
    if (input == null) return null;
    return ParsedToolCall(name: name, input: input);
  }
}
