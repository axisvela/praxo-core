import 'dart:io';

import '../lib/praxo.dart';

class RecordingSink implements EventSink {
  final List<String> types = [];

  @override
  void emit(Event event) => types.add(event.type);
}

class ScriptedModel implements Model {
  final List<dynamic> steps;
  var next = 0;

  ScriptedModel(this.steps);

  @override
  Response generate(Request request) {
    if (next >= steps.length) throw StateError('script exhausted');
    final step = steps[next++] as Map<String, dynamic>;
    final calls = Json.array(step, 'toolCalls')
        .map((item) => ToolCall(
              id: Json.string(item, 'id') ?? '',
              name: Json.string(item, 'name') ?? '',
              arguments: Json.get(item, 'arguments') is Map<String, dynamic>
                  ? Json.get(item, 'arguments') as Map<String, dynamic>
                  : <String, dynamic>{},
            ))
        .toList();
    return Response(
      message: Message.assistant(Json.string(step, 'content') ?? '', calls),
      usage: Usage(
        inputTokens: Json.integer(step, 'inputTokens'),
        outputTokens: Json.integer(step, 'outputTokens'),
      ),
    );
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String errorCode(Object error) => error is PraxoError ? error.code : '';

void runToolcall(dynamic input, dynamic expect) {
  final operation = Json.string(input, 'operation') ?? '';
  final content = Json.string(input, 'content') ?? '';
  if (operation == 'strip') {
    final got = ToolCallParser.stripMarkup(content);
    check(got == (Json.string(expect, 'text') ?? ''), 'strip: got $got');
    return;
  }
  final call = ToolCallParser.parse(content);
  if (Json.boolean(expect, 'nil')) {
    check(call == null, 'expected nil');
    return;
  }
  check(call != null, 'expected a tool call');
  check(call!.name == (Json.string(expect, 'name') ?? ''), 'name: got ${call.name}');
  check(Json.equals(call.input, Json.get(expect, 'input') ?? {}), 'input mismatch');
}

void runJsonschema(dynamic input, dynamic expect) {
  final errors = validate(Json.get(input, 'schema'), Json.get(input, 'data'));
  final paths = errors.map((error) => error.path).toList()..sort();
  final expected = Json.array(expect, 'errorPaths').map((item) => '$item').toList()
    ..sort();
  check(errors.isEmpty == Json.boolean(expect, 'valid'), 'valid mismatch');
  check(paths.join('\u0000') == expected.join('\u0000'),
      'errorPaths: got ${paths.join(', ')}');
}

void runPlugin(dynamic input, dynamic expect) {
  final raw = Json.string(input, 'raw') ??
      Json.stringify(Json.get(input, 'manifest') ?? {});
  PluginManifest? manifest;
  try {
    manifest = parseManifest(raw);
  } catch (_) {
    manifest = null;
  }
  check((manifest != null) == Json.boolean(expect, 'valid'), 'valid mismatch');
  if (manifest == null) return;
  final id = Json.string(expect, 'id');
  if (id != null) check(manifest.id == id, 'id: got ${manifest.id}');
  final kind = Json.string(expect, 'kind');
  if (kind != null) check(manifest.kind == kind, 'kind: got ${manifest.kind}');
}

void runMemory(dynamic input, dynamic expect) {
  final store = MemoryStore();
  for (final put in Json.array(input, 'puts')) {
    final record = Json.get(put, 'record') ?? {};
    store.put(
      Json.string(put, 'session') ?? '',
      MemoryRecord(
        id: Json.string(record, 'id') ?? '',
        frame: Json.string(record, 'frame') ?? '',
        content: Json.string(record, 'content') ?? '',
        createdAt: Json.string(record, 'createdAt'),
      ),
    );
  }
  final records = store.search(Json.string(input, 'session') ?? '',
      Json.string(input, 'query') ?? '', Json.integer(input, 'limit'));
  final ids = records.isEmpty ? null : records.map((record) => record.id).toList();
  final contents =
      records.isEmpty ? null : records.map((record) => record.content).toList();
  check(Json.equals(ids, Json.get(expect, 'ids')), 'ids mismatch');
  check(Json.equals(contents, Json.get(expect, 'contents')), 'contents mismatch');
}

void runEvent(dynamic input, dynamic expect) {
  final events = Json.array(input, 'events')
      .map((type) => Event(type: '$type', sessionId: 's1'))
      .toList();
  if ((Json.string(input, 'sink') ?? 'filter') == 'multi') {
    final count = Json.integer(input, 'sinkCount', 1) < 1
        ? 1
        : Json.integer(input, 'sinkCount', 1);
    final sinks = List.generate(count, (_) => RecordingSink());
    final multi = MultiSink(sinks);
    for (final event in events) {
      multi.emit(event);
    }
    check(Json.equals(sinks.map((sink) => sink.types).toList(), Json.get(expect, 'perSink')),
        'perSink mismatch');
    return;
  }
  final sink = RecordingSink();
  final predicate = Json.get(input, 'predicateTypes');
  final allowed = predicate == null
      ? null
      : (predicate as List).map((item) => '$item').toSet();
  final filter = FilterSink(sink, (event) => allowed == null || allowed.contains(event.type));
  for (final event in events) {
    filter.emit(event);
  }
  final delivered = sink.types.isEmpty ? null : sink.types;
  check(Json.equals(delivered, Json.get(expect, 'delivered')), 'delivered mismatch');
}

void runStream(dynamic expect) {
  check(Json.equals(streamKinds, Json.get(expect, 'kinds')), 'kinds mismatch');
}

void runCheckpoint(dynamic input, dynamic expect) {
  final allowlist = CheckpointAllowlist();
  for (final type in Json.array(input, 'registered')) {
    allowlist.register('$type');
  }
  final operation = Json.string(input, 'operation') ?? 'roundtrip';
  final type = Json.string(input, 'type') ?? '';
  final value = Json.get(input, 'value');
  if (operation == 'roundtrip') {
    final data = allowlist.marshal(type, value);
    check(Json.equals(allowlist.unmarshal(data), Json.get(expect, 'value')),
        'value mismatch');
    return;
  }
  var code = '';
  try {
    if (operation == 'marshal') {
      allowlist.marshal(type, value);
    } else if (operation == 'unmarshal') {
      allowlist.unmarshal(Json.stringify({'type': type, 'data': value}));
    } else {
      throw const PraxoError('CHECKPOINT_ERROR', 'unknown operation');
    }
  } on PraxoError catch (error) {
    code = error.code;
  }
  check(code == (Json.string(expect, 'errorCode') ?? ''), 'errorCode: got $code');
}

void runPolicy(dynamic input, dynamic expect) {
  final root = Directory.systemTemp.createTempSync('praxo-policy-');
  try {
    for (final dir in Json.array(input, 'makeDirs')) {
      Directory('${root.path}/$dir').createSync(recursive: true);
    }
    final grants = <PathGrant>[];
    for (final item in Json.array(input, 'grants')) {
      final grantRoot = '${root.path}/${Json.string(item, 'root') ?? ''}';
      Directory(grantRoot).createSync(recursive: true);
      grants.add(PathGrant(
        root: grantRoot,
        access: Json.string(item, 'access') ?? 'read',
      ));
    }
    final checker = PathChecker(grants);
    final target = '${root.path}/${Json.string(input, 'target') ?? ''}';
    final need = Json.string(input, 'need') ?? 'read';
    if (Json.boolean(expect, 'error')) {
      var caught = false;
      try {
        checker.check(target, need);
      } on PraxoError {
        caught = true;
      }
      check(caught, 'expected a policy error');
      return;
    }
    final allowed = checker.check(target, need).allowed;
    check(allowed == Json.boolean(expect, 'allowed'), 'allowed mismatch');
  } finally {
    root.deleteSync(recursive: true);
  }
}

void runContext(dynamic input, dynamic expect) {
  final messages = Json.array(input, 'messages')
      .map((item) => Message.text(
            Json.string(item, 'role') ?? '',
            Json.string(item, 'content') ?? '',
          ))
      .toList();
  if ((Json.string(input, 'operation') ?? '') == 'estimate') {
    final tokens = estimateTokens(messages);
    check(tokens == Json.integer(expect, 'tokens'), 'tokens: got $tokens');
    return;
  }
  final budget = Json.get(input, 'budget') ?? {};
  final context = ContextBudget(
    maxTokens: Json.integer(budget, 'maxTokens'),
    keepRecent: Json.integer(budget, 'keepRecent'),
  );
  final (output, ok) = context.compact(messages);
  check(ok == Json.boolean(expect, 'ok'), 'ok mismatch');
  if (!ok) return;
  final tokens = estimateTokens(output);
  check(tokens == Json.integer(expect, 'tokens'), 'tokens: got $tokens');
  check(
    Json.equals(output.map((message) => messageWire(message)).toList(),
        Json.get(expect, 'messages')),
    'messages mismatch',
  );
}

void runMiddleware(dynamic input, dynamic expect) {
  final operation = Json.string(input, 'operation') ?? '';
  switch (operation) {
    case 'pii':
      final got = PiiRedactor().redact(Json.string(input, 'text') ?? '');
      check(got == (Json.string(expect, 'text') ?? ''), 'text mismatch');
      break;
    case 'pii-value':
      check(
        Json.equals(PiiRedactor().redactValue(Json.get(input, 'value')),
            Json.get(expect, 'value')),
        'value mismatch',
      );
      break;
    case 'structured':
      final repair = Json.string(input, 'repairOutput');
      final output = StructuredOutput(
        schema: Json.get(input, 'schema') as Map<String, dynamic>? ?? {},
        maxRepairs: Json.integer(input, 'maxRepairs'),
        repairer: repair == null ? null : (_) => repair,
      );
      final (text, code) = output.apply(Json.string(input, 'output') ?? '');
      if (Json.boolean(expect, 'ok')) {
        check(text == (Json.string(expect, 'output') ?? ''), 'output mismatch');
      } else {
        check(code == (Json.string(expect, 'errorCode') ?? ''), 'errorCode mismatch');
      }
      break;
    case 'call-limit':
      final limit = CallLimit(
        modelLimit: Json.integer(input, 'modelLimit'),
        toolLimit: Json.integer(input, 'toolLimit'),
      );
      final outcomes = <String>[];
      for (final call in Json.array(input, 'calls')) {
        try {
          if (call == 'model') {
            limit.beforeModel();
          } else {
            limit.beforeTool();
          }
          outcomes.add('ok');
        } on PraxoError catch (error) {
          outcomes.add(error.code);
        }
      }
      check(Json.equals(outcomes, Json.get(expect, 'outcomes')), 'outcomes mismatch');
      break;
    case 'tool-selection':
      final selection = ToolSelection(
          Json.array(input, 'selected').map((item) => '$item'));
      final tools = Json.array(input, 'tools')
          .map((name) => ToolSpec(name: '$name'))
          .toList();
      final advertised = selection.filter(tools).map((tool) => tool.name).toList();
      check(Json.equals(advertised, Json.get(expect, 'advertised')),
          'advertised mismatch');
      var reject = 'ok';
      try {
        selection.reject(Json.string(input, 'requested') ?? '');
      } on PraxoError catch (error) {
        reject = error.code;
      }
      check(reject == (Json.string(expect, 'reject') ?? ''), 'reject mismatch');
      break;
    case 'fallback':
      final content = Json.string(input, 'fallbackContent') ?? '';
      final handler = fallbackModel((request) => Response(
            message: Message.assistant(content),
          ))((request) {
        throw const PraxoError('PRIMARY_FAILED', 'primary');
      });
      check(handler(const Request()).message.content == content, 'output mismatch');
      break;
    default:
      throw StateError('unknown middleware operation $operation');
  }
}

void runAgentLoop(dynamic input, dynamic expect) {
  var invocations = 0;
  final registry = Registry();
  for (final item in Json.array(input, 'tools')) {
    registry.register(FuncTool(
      Json.string(item, 'name') ?? '',
      Json.string(item, 'description') ?? '',
      (arguments) {
        invocations++;
        return arguments;
      },
    ));
  }
  final sink = RecordingSink();
  final options = AgentOptions(
    ScriptedModel(Json.array(input, 'script')),
    tools: registry,
    events: sink,
    maxSteps: Json.integer(input, 'maxSteps'),
    maxTokens: Json.integer(input, 'maxTokens'),
  );
  RunResult? result;
  Object? failure;
  try {
    result = runAgent(options, Session(id: 's1'), Json.string(input, 'prompt') ?? '');
  } catch (error) {
    failure = error;
  }
  if (Json.boolean(expect, 'error')) {
    check(failure != null, 'unexpected success');
    final expected = Json.string(expect, 'errorCode');
    if (expected != null) {
      check(errorCode(failure!) == expected, 'errorCode mismatch');
    }
  } else {
    check(failure == null, 'unexpected failure: $failure');
    check(result!.output == (Json.string(expect, 'output') ?? ''), 'output mismatch');
    check(result.steps == Json.integer(expect, 'steps'), 'steps mismatch');
  }
  check(invocations == Json.integer(expect, 'toolInvocations'), 'tool invocations mismatch');
  final events = sink.types.isEmpty ? null : sink.types;
  check(Json.equals(events, Json.get(expect, 'events')), 'events mismatch');
}

void runVector(String group, dynamic vector) {
  final input = Json.get(vector, 'input') ?? {};
  final expect = Json.get(vector, 'expect') ?? {};
  switch (group) {
    case 'toolcall':
      runToolcall(input, expect);
      break;
    case 'jsonschema':
      runJsonschema(input, expect);
      break;
    case 'plugin':
      runPlugin(input, expect);
      break;
    case 'memory':
      runMemory(input, expect);
      break;
    case 'event':
      runEvent(input, expect);
      break;
    case 'stream':
      runStream(expect);
      break;
    case 'checkpoint':
      runCheckpoint(input, expect);
      break;
    case 'policy':
      runPolicy(input, expect);
      break;
    case 'context':
      runContext(input, expect);
      break;
    case 'middleware':
      runMiddleware(input, expect);
      break;
    case 'agent-loop':
      runAgentLoop(input, expect);
      break;
    default:
      throw StateError('no runner for group $group');
  }
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent.parent.parent;
  final version = File('${root.path}/spec/SPEC_VERSION').readAsStringSync().trim();
  final files = Directory('${root.path}/spec/vectors')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final failures = <String>[];
  final seen = <String, String>{};
  for (final file in files) {
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    dynamic parsed;
    try {
      parsed = Json.parse(file.readAsStringSync());
    } catch (error) {
      failures.add('$name: invalid vector file: $error');
      continue;
    }
    final group = Json.string(parsed, 'group') ?? '';
    if (Json.string(parsed, 'specVersion') != version) {
      failures.add('$name: specVersion mismatch');
    }
    if (name != group) failures.add('$name: group mismatch');
    for (final vector in Json.array(parsed, 'vectors')) {
      final id = Json.string(vector, 'id') ?? '';
      if (seen.containsKey(id)) {
        failures.add('$group/$id: duplicate id with ${seen[id]}');
      }
      seen[id] = group;
      try {
        runVector(group, vector);
      } catch (error) {
        failures.add('$group/$id: $error');
      }
    }
  }
  if (failures.isEmpty) {
    stdout.writeln('all spec vectors passed');
    exit(0);
  }
  stderr.writeln(failures.join('\n'));
  exit(1);
}
