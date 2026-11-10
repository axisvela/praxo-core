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
