import 'errors.dart';
import 'jsonschema.dart';
import 'json.dart';
import 'models.dart';

typedef ModelHandler = Response Function(Request request);
typedef ModelMiddleware = ModelHandler Function(ModelHandler next);

class PiiRedactor {
  static final List<(RegExp, String)> _rules = [
    (RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '[REDACTED:email]'),
    (RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), '[REDACTED:ssn]'),
    (RegExp(r'\b(?:\d{4}[ -]?){3}\d{4}\b'), '[REDACTED:credit_card]'),
  ];

  String redact(String text) {
    var output = text;
    for (final (pattern, replacement) in _rules) {
      output = output.replaceAll(pattern, replacement);
    }
    return output;
  }

  dynamic redactValue(dynamic value) {
    if (value is String) return redact(value);
    if (value is List) return value.map(redactValue).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry(key, redactValue(item)));
    }
    return value;
  }
}

class StructuredOutput {
  final Map<String, dynamic> schema;
  final int maxRepairs;
  final String? Function(String output)? repairer;

  const StructuredOutput({
    required this.schema,
    this.maxRepairs = 0,
    this.repairer,
  });

  (String?, String?) apply(String text) {
    var output = text;
    for (var attempt = 0; attempt <= maxRepairs; attempt++) {
      try {
        final data = extractJson(output);
        if (validate(schema, data).isEmpty) return (output, null);
      } catch (_) {}
      if (attempt == maxRepairs && repairer == null) break;
      if (repairer == null) break;
      final repaired = repairer!(output);
      if (repaired == null || repaired.trim().isEmpty) break;
      output = repaired;
    }
    return (null, 'AGENT_STRUCTURED_OUTPUT');
  }
}

dynamic extractJson(String text) {
  var value = text.trim();
  if (value.startsWith('```')) {
    final newline = value.indexOf('\n');
    if (newline >= 0) value = value.substring(newline + 1);
    value = value.replaceFirst(RegExp(r'^`+'), '');
    value = value.replaceFirst(RegExp(r'`+\s*$'), '');
    value = value.trim();
  }
  final object = value.indexOf('{');
  final array = value.indexOf('[');
  int start;
  if (object >= 0 && array >= 0) {
    start = object < array ? object : array;
  } else {
    start = object >= 0 ? object : array;
  }
  if (start < 0) {
    throw const PraxoError('AGENT_STRUCTURED_OUTPUT', 'output does not contain JSON');
  }
  return Json.parse(value.substring(start));
}

class CallLimit {
  final int modelLimit;
  final int toolLimit;
  int _models = 0;
  int _tools = 0;

  CallLimit({this.modelLimit = 0, this.toolLimit = 0});

  void beforeModel() {
    _models++;
    if (modelLimit > 0 && _models > modelLimit) {
      throw const PraxoError('AGENT_MODEL_CALL_LIMIT', 'model call limit');
    }
  }

  void beforeTool() {
    _tools++;
    if (toolLimit > 0 && _tools > toolLimit) {
      throw const PraxoError('AGENT_TOOL_CALL_LIMIT', 'tool call limit');
    }
  }
}

class ToolSelection {
  final Set<String> selected;

  ToolSelection(Iterable<String> selected) : selected = selected.toSet();

  List<ToolSpec> filter(List<ToolSpec> tools) =>
      tools.where((tool) => selected.contains(tool.name)).toList();

  void reject(String name) {
    if (!selected.contains(name)) {
      throw const PraxoError('AGENT_TOOL_NOT_SELECTED', 'tool not selected');
    }
  }
}

ModelMiddleware fallbackModel(ModelHandler fallback) {
  return (ModelHandler next) {
    return (Request request) {
      try {
        return next(request);
      } catch (_) {
        return fallback(request);
      }
    };
  };
}
