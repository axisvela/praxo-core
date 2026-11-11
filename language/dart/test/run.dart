import 'dart:io';

import '../lib/praxo_core.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final call = ToolCallParser.parse('{"name":"echo","input":{"text":"hi"}}');
  check(call != null && call.name == 'echo' && call.input['text'] == 'hi',
      'toolcall');
  check(
    ToolCallParser.stripMarkup(
            'hello<tool_call name="echo">{"text":"hi"}</tool_call>world') ==
        'helloworld',
    'toolcall strip',
  );

  final schema = Json.parse(
      '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}');
  final errors = validate(schema, <String, dynamic>{});
  check(errors.length == 1 && errors.first.path == r'$.name', 'jsonschema');
  check(validate(schema, {'name': 'ok'}).isEmpty, 'jsonschema valid');

  final manifest = parseManifest(
      '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",'
      '"kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},'
      '"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},'
      '"health":{},"isolation":"process"}');
  check(manifest.id == 'com.example.echo', 'plugin');

  final store = MemoryStore();
  store.put(
      's1',
      MemoryRecord(
          id: 'm1', content: 'Alpha', createdAt: '2026-01-01T00:00:00Z'));
  store.put(
      's1',
      MemoryRecord(
          id: 'm2', content: 'ALPHABET', createdAt: '2026-01-02T00:00:00Z'));
  check(
      store.search('s1', 'alpha', 10).map((record) => record.id).join(',') ==
          'm2,m1',
      'memory');

  final allowlist = CheckpointAllowlist();
  allowlist.register('spec.payload');
  final data = allowlist.marshal('spec.payload', {'value': 'x'});
  check(Json.equals(allowlist.unmarshal(data), {'value': 'x'}), 'checkpoint');

  final root = Directory.systemTemp.createTempSync('praxo-dart-tests-');
  try {
    final grant = '${root.path}/root';
    final checker = PathChecker([PathGrant(root: grant, access: 'readwrite')]);
    check(checker.check('$grant/a.txt', 'read').allowed, 'policy allow');
    check(!checker.check('${root.path}/root-evil/x.txt', 'read').allowed,
        'policy sibling');
    check(!checker.check('$grant/../outside/x.txt', 'read').allowed,
        'policy traversal');
  } finally {
    root.deleteSync(recursive: true);
  }

  final messages = <Message>[Message.text(roleSystem, 'sys')];
  for (var index = 0; index < 10; index++) {
    messages.add(Message.text(roleUser, 'message $index'));
  }
  check(estimateTokens(messages) == 64, 'context estimate');
  final (output, ok) =
      const ContextBudget(maxTokens: 30, keepRecent: 2).compact(messages);
  check(ok, 'context compact');
  check(estimateTokens(output) == 25, 'context compact tokens');
  check(output[1].content == '[context compacted: 8 older messages omitted]',
      'context marker');

  check(
      PiiRedactor().redact('email a@b.com') == 'email [REDACTED:email]', 'pii');
  final structured = StructuredOutput(
    schema: Json.parse(
        '{"type":"object","properties":{"value":{"type":"integer"}},"required":["value"]}'),
  );
  final (text, code) = structured.apply('{"value":1}');
  check(text == '{"value":1}' && code == null, 'structured');

  final limit = CallLimit(modelLimit: 1, toolLimit: 0);
  limit.beforeModel();
  var caught = false;
  try {
    limit.beforeModel();
  } on PraxoError {
    caught = true;
  }
  check(caught, 'call limit');

  final selection = ToolSelection(['echo']);
  final tools = [const ToolSpec(name: 'echo'), const ToolSpec(name: 'other')];
  check(selection.filter(tools).length == 1, 'tool selection');
  caught = false;
  try {
    selection.reject('other');
  } on PraxoError {
    caught = true;
  }
  check(caught, 'tool selection reject');

  final handler = fallbackModel(
    (request) => Response(message: Message.assistant('fallback')),
  )((request) {
    throw const PraxoError('PRIMARY_FAILED', 'primary');
  });
  check(handler(const Request()).message.content == 'fallback', 'fallback');

  var invocations = 0;
  final registry = Registry();
  registry.register(FuncTool('echo', 'Echo', (arguments) {
    invocations++;
    return arguments;
  }));
  final sink = RecordingSink();
  final options = AgentOptions(
    _TestModel([
      Message(
        role: roleAssistant,
        content: '',
        toolCalls: [
          const ToolCall(id: 'c1', name: 'echo', arguments: {'text': 'hi'})
        ],
      ),
      Message.assistant('done'),
    ]),
    tools: registry,
    events: sink,
  );
  final result = runAgent(options, const Session(id: 's1'), 'go');
  check(result.output == 'done' && result.steps == 2 && invocations == 1,
      'agent loop');
  check(sink.types.join(',') == 'run.started,tool.call,run.completed',
      'agent events');

  final recorded = <String, dynamic>{};
  final adapter = OpenAICompatibleModel(
    baseUrl: 'https://api.example.com/v1/',
    model: 'provider-model',
    apiKey: 'secret',
    transport: (path, payload) {
      recorded['path'] = path;
      recorded['payload'] = payload;
      return {
        'choices': [
          {
            'message': {
              'content': 'done',
              'tool_calls': [
                {
                  'id': 'call-1',
                  'type': 'function',
                  'function': {
                    'name': 'echo',
                    'arguments': '{"text":"hi"}',
                  },
                }
              ],
            },
            'finish_reason': 'tool_calls',
          }
        ],
        'usage': {'prompt_tokens': 3, 'completion_tokens': 2},
      };
    },
  );
  final adapterRequest = Request(
    messages: [
      Message.text(roleSystem, 'sys'),
      Message.text(roleUser, 'hi'),
      Message(
        role: roleAssistant,
        content: '',
        toolCalls: [
          const ToolCall(id: 'c1', name: 'echo', arguments: {'text': 'hi'})
        ],
      ),
      Message.tool('{"ok":true}', 'c1'),
    ],
    tools: [
      const ToolSpec(
          name: 'echo', description: 'Echo', parameters: {'type': 'object'})
    ],
    toolChoice: 'auto',
  );
  final adapterResponse = adapter.generate(adapterRequest);
  check(recorded['path'] == '/chat/completions', 'adapter path');
  final payload = recorded['payload'] as Map<String, dynamic>;
  check(payload['model'] == 'provider-model', 'adapter model');
  check(payload['tool_choice'] == 'auto', 'adapter tool choice');
  final payloadTools = payload['tools'] as List;
  check((payloadTools.first as Map)['type'] == 'function', 'adapter tool type');
  final payloadMessages = payload['messages'] as List;
  check((payloadMessages[2] as Map)['tool_calls'] != null,
      'adapter assistant calls');
  check((payloadMessages[3] as Map)['tool_call_id'] == 'c1', 'adapter tool id');
  check(adapterResponse.message.content == 'done', 'adapter content');
  check(adapterResponse.message.toolCalls.single.arguments['text'] == 'hi',
      'adapter arguments');
  check(
      adapterResponse.usage.inputTokens == 3 &&
          adapterResponse.usage.outputTokens == 2,
      'adapter usage');
  check(adapterResponse.finishReason == 'tool_calls', 'adapter finish');

  var httpCode = '';
  try {
    OpenAICompatibleModel.decodeHttpResponse(503, 'down');
  } on PraxoError catch (error) {
    httpCode = error.code;
  }
  check(httpCode == 'PROVIDER_HTTP', 'adapter http error');

  var invalidCode = '';
  try {
    OpenAICompatibleModel(
      baseUrl: 'https://api.example.com',
      model: 'm',
      transport: (path, payload) => {
        'choices': [
          {
            'message': {
              'tool_calls': [
                {
                  'id': 'c',
                  'function': {'name': 'x', 'arguments': '{bad'},
                }
              ],
            },
          }
        ],
      },
    ).generate(const Request());
  } on PraxoError catch (error) {
    invalidCode = error.code;
  }
  check(invalidCode == 'PROVIDER_RESPONSE', 'adapter invalid arguments');

  var missingCode = '';
  try {
    OpenAICompatibleModel(baseUrl: '', model: 'm').generate(const Request());
  } on PraxoError catch (error) {
    missingCode = error.code;
  }
  check(missingCode == 'PROVIDER_HTTP', 'adapter missing base url');

  final asyncResponse = await OpenAICompatibleModel(
    baseUrl: 'https://api.example.com',
    model: 'm',
    asyncTransport: (path, payload) async => {
      'choices': [
        {
          'message': {'content': 'async'},
        }
      ],
    },
  ).generateAsync(const Request());
  check(asyncResponse.message.content == 'async', 'adapter async');

  final anthropicRecorded = <String, dynamic>{};
  final anthropic = AnthropicModel(
    model: 'claude-test',
    apiKey: 'ak',
    transport: (path, payload) {
      anthropicRecorded['path'] = path;
      anthropicRecorded['payload'] = payload;
      return {
        'content': [
          {'type': 'text', 'text': 'hello'},
          {
            'type': 'tool_use',
            'id': 'tool-1',
            'name': 'echo',
            'input': {'text': 'hi'},
          }
        ],
        'stop_reason': 'end_turn',
        'usage': {
          'input_tokens': 3,
          'output_tokens': 4,
          'cache_read_input_tokens': 2,
        },
      };
    },
  );
  final providerRequest = Request(
    messages: [
      Message.text(roleSystem, 'be brief'),
      Message.text(roleUser, 'hi'),
    ],
    tools: [
      const ToolSpec(
          name: 'echo', description: 'Echo', parameters: {'type': 'object'})
    ],
    toolChoice: 'auto',
  );
  final anthropicResponse = anthropic.generate(providerRequest);
  check(anthropicRecorded['path'] == '/v1/messages', 'anthropic path');
  final anthropicPayload =
      anthropicRecorded['payload'] as Map<String, dynamic>;
  check(anthropicPayload['system'] == 'be brief', 'anthropic system');
  check((anthropicPayload['tools'] as List).isNotEmpty, 'anthropic tools');
  check(anthropicResponse.message.content == 'hello', 'anthropic content');
  check(anthropicResponse.message.toolCalls.single.id == 'tool-1',
      'anthropic call id');
  check(anthropicResponse.usage.cachedTokens == 2, 'anthropic cached');

  final geminiRecorded = <String, dynamic>{};
  final gemini = GeminiModel(
    model: 'gemini-test',
    apiKey: 'gk',
    transport: (path, payload) {
      geminiRecorded['path'] = path;
      geminiRecorded['payload'] = payload;
      return {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'hello'},
                {
                  'functionCall': {
                    'name': 'echo',
                    'args': {'text': 'hi'},
                  }
                }
              ],
            },
            'finishReason': 'STOP',
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 3,
          'candidatesTokenCount': 4,
        },
      };
    },
  );
  final geminiResponse = gemini.generate(providerRequest);
  check((geminiRecorded['path'] as String).endsWith(':generateContent'),
      'gemini path');
  final geminiPayload = geminiRecorded['payload'] as Map<String, dynamic>;
  check(
      ((geminiPayload['system_instruction'] as Map)['parts'] as List).isNotEmpty,
      'gemini system');
  check(geminiPayload['toolConfig'] != null, 'gemini tools');
  check(geminiResponse.message.toolCalls.single.name == 'echo',
      'gemini call name');
  check(geminiResponse.usage.inputTokens == 3, 'gemini usage');

  final anthropicAsync = await AnthropicModel(
    model: 'claude-test',
    apiKey: 'ak',
    asyncTransport: (path, payload) async => {
      'content': [
        {'type': 'text', 'text': 'async'},
      ],
    },
  ).generateAsync(const Request());
  check(anthropicAsync.message.content == 'async', 'anthropic async');

  final geminiAsync = await GeminiModel(
    model: 'gemini-test',
    apiKey: 'gk',
    asyncTransport: (path, payload) async => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'async'},
            ],
          },
        }
      ],
    },
  ).generateAsync(const Request());
  check(geminiAsync.message.content == 'async', 'gemini async');

  String? harmovelaPath;
  Map<String, dynamic>? harmovelaEnvelope;
  final harmovelaTransport = (String baseUrl, String path, String body,
      Map<String, String> headers) {
    harmovelaPath = path;
    check(headers['content-type'] == 'application/json',
        'harmovela content type');
    harmovelaEnvelope = Json.parse(body) as Map<String, dynamic>;
    return const HarmovelaResponse(204, '');
  };
  final harmovelaSink = HarmovelaSink(
    baseUrl: 'http://127.0.0.1:8790/aep/api/',
    transport: harmovelaTransport,
    clock: () => (seconds: 1700000000, nanos: 123456789),
  );
  harmovelaSink.emit(const Event(
    type: 'tool.call',
    sessionId: 's1',
    runId: 'run-123',
    data: {'name': 'echo'},
  ));
  check(harmovelaPath == '/events', 'harmovela path');
  final envelope = harmovelaEnvelope!;
  check(envelope['spec_version'] == '0.2', 'harmovela spec version');
  check(envelope['id'] == 'run-123-1700000000123456789', 'harmovela id');
  check(envelope['type'] == 'tool.call', 'harmovela type');
  check(envelope['source'] == 'praxo-core', 'harmovela source');
  check(envelope['created_at'] == '2023-11-14T22:13:20.123456789Z',
      'harmovela created_at');
  final harmovelaPayload = envelope['payload'] as Map<String, dynamic>;
  check(harmovelaPayload['name'] == 'echo', 'harmovela payload name');
  check(harmovelaPayload['session_id'] == 's1', 'harmovela payload session');
  check(harmovelaPayload['run_id'] == 'run-123', 'harmovela payload run');

  final harmovelaFailure = HarmovelaSink(
    baseUrl: 'http://127.0.0.1:8790/aep/api',
    transport: (baseUrl, path, body, headers) =>
        const HarmovelaResponse(500, 'boom'),
    clock: () => (seconds: 1700000000, nanos: 0),
  );
  Object? harmovelaError;
  try {
    harmovelaFailure.emit(
        const Event(type: 'tool.call', sessionId: 's1', runId: 'run-123'));
  } on PraxoError catch (error) {
    harmovelaError = error;
  }
  check(harmovelaError is PraxoError, 'harmovela error type');
  final failure = harmovelaError as PraxoError;
  check(failure.code == 'HARMOVELA_HTTP', 'harmovela error code');
  check(failure.message.contains('500'), 'harmovela error status');
  check(failure.message.contains('boom'), 'harmovela error body');

  Object? harmovelaMissing;
  try {
    HarmovelaSink(
      baseUrl: '',
      transport: harmovelaTransport,
      clock: () => (seconds: 1700000000, nanos: 0),
    ).emit(const Event(type: 'tool.call', sessionId: 's1'));
  } on PraxoError catch (error) {
    harmovelaMissing = error;
  }
  check(harmovelaMissing is PraxoError, 'harmovela missing base url type');
  check((harmovelaMissing as PraxoError).code == 'HARMOVELA_URL',
      'harmovela missing base url');

  stdout.writeln('dart core tests passed');
}

class RecordingSink implements EventSink {
  final List<String> types = [];

  @override
  void emit(Event event) => types.add(event.type);
}

class _TestModel implements Model {
  final List<Message> messages;
  var next = 0;

  _TestModel(this.messages);

  @override
  Response generate(Request request) => Response(message: messages[next++]);
}
