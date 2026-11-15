import 'dart:io';

import '../../lib/praxo_core.dart';

class SchemaRegistry extends Registry {
  SchemaRegistry(this.schema);

  final ToolSpec schema;

  @override
  List<ToolSpec> specs() => [schema];
}

String envOr(String name, String fallback) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? fallback : value;
}

String getTime(Map<String, dynamic> arguments) {
  final now = DateTime.now();
  if (arguments['zone'] == 'local') {
    return now.toLocal().toIso8601String();
  }
  return now.toUtc().toIso8601String();
}

Decision authorize(Action action) {
  if (action.kind == 'model.generate') {
    return const Decision(allowed: true);
  }
  if (action.kind == 'tool.invoke') {
    return Decision(
      allowed: action.toolName == 'get_time',
      reason: 'only get_time is permitted',
    );
  }
  return const Decision(allowed: false, reason: 'unsupported action');
}

void main() {
  final baseUrl =
      envOr('PRAXO_BASE_URL', 'http://localhost:11434/v1');
  final modelName = envOr('PRAXO_MODEL', 'qwen3.5:4b');
  final apiKey = envOr('PRAXO_API_KEY', '');
  final prompt = envOr(
    'PRAXO_PROMPT',
    'What time is it? Use get_time with zone set to utc and reply with the time.',
  );

  final schema = ToolSpec(
    name: 'get_time',
    description:
        'Return the current time in ISO 8601 format for the requested zone.',
    parameters: {
      'type': 'object',
      'properties': {
        'zone': {
          'type': 'string',
          'enum': ['utc', 'local'],
          'description': 'utc or local; defaults to utc',
        },
      },
    },
    risk: 'read',
  );
  final registry = SchemaRegistry(schema)
    ..register(FuncTool(
      'get_time',
      schema.description,
      getTime,
    ));

  final model = OpenAICompatibleModel(
    baseUrl: baseUrl,
    model: modelName,
    apiKey: apiKey.isEmpty ? null : apiKey,
  );
  final options = AgentOptions(
    model,
    tools: registry,
    systemPrompt:
        'You are a concise assistant. Use the provided tools when they help.',
    maxSteps: 4,
    allowedTools: const ['get_time'],
    policy: authorize,
  );

  try {
    final result =
        runAgent(options, const Session(id: 'live-model'), prompt);
    print(result.output);
  } catch (error) {
    stderr.writeln('live model run failed: $error\n');
    stderr.writeln(
        'Check PRAXO_BASE_URL ($baseUrl), PRAXO_MODEL ($modelName), and PRAXO_API_KEY');
    exit(1);
  }
}
