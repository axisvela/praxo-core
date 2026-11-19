import 'dart:convert';
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

  final defaultGuards = AgentOptions(StaticModel('ok'));
  check(!defaultGuards.requirePolicy && !defaultGuards.requireToolScope,
      'safe-default guards off by default');
  check(runAgent(defaultGuards, const Session(id: 's1'), 'go').output == 'ok',
      'defaults preserve behavior');

  var policyGuard = false;
  try {
    Agent(AgentOptions(StaticModel('ok'), requirePolicy: true));
  } on PraxoError catch (error) {
    policyGuard = error.code == 'AGENT_INVALID_OPTIONS';
  }
  check(policyGuard, 'require policy rejects missing policy');

  final guardedPolicy = Agent(AgentOptions(
    StaticModel('ok'),
    requirePolicy: true,
    policy: (action) => const Decision(allowed: true),
  ));
  check(guardedPolicy.options.policy != null,
      'require policy accepts configured policy');

  var scopeGuard = false;
  try {
    Agent(AgentOptions(StaticModel('ok'), requireToolScope: true));
  } on PraxoError catch (error) {
    scopeGuard = error.code == 'AGENT_INVALID_OPTIONS';
  }
  check(scopeGuard, 'require tool scope rejects empty allowed tools');

  final guardedScope = Agent(AgentOptions(
    StaticModel('ok'),
    requireToolScope: true,
    allowedTools: const ['echo'],
  ));
  check(guardedScope.options.allowedTools.isNotEmpty,
      'require tool scope accepts allowed tools');

  final approveEffects = <int>[0];
  final approveEvents = RecordingSink();
  final approveOutput = _runHitl(
    approveEffects,
    (_) => const InterruptDecision(action: interruptApprove),
    events: approveEvents,
  );
  check(approveEffects[0] == 1 && approveOutput.contains('written'),
      'hitl approve');
  check(
      approveEvents.types.join(',') ==
          'run.started,tool.interrupt,tool.call,run.completed',
      'hitl approve events');

  final fallbackEffects = <int>[0];
  final fallbackOutput = _runHitl(
    fallbackEffects,
    null,
    approval: (_) => true,
  );
  check(fallbackEffects[0] == 1 && fallbackOutput.contains('written'),
      'hitl approval fallback');

  var fallbackDenied = false;
  try {
    _runHitl(<int>[0], null, approval: (_) => false);
  } on PraxoError catch (error) {
    fallbackDenied = error.code == 'AGENT_APPROVAL_DENIED';
  }
  check(fallbackDenied, 'hitl approval fallback denial');

  final editEffects = <int>[0];
  var editDenied = false;
  try {
    _runHitl(
      editEffects,
      (_) => const InterruptDecision(
        action: interruptEdit,
        arguments: {'text': 'hello', 'visibility': 'private'},
      ),
    );
  } on PraxoError catch (error) {
    editDenied = error.code == 'AGENT_POLICY_DENIED';
  }
  check(editDenied && editEffects[0] == 0, 'hitl edit reauthorization denial');

  final rejectEffects = <int>[0];
  var rejectDenied = false;
  try {
    _runHitl(
      rejectEffects,
      (_) => const InterruptDecision(
        action: interruptReject,
        reason: 'not allowed',
      ),
    );
  } on PraxoError catch (error) {
    rejectDenied = error.code == 'AGENT_APPROVAL_DENIED' &&
        error.message.contains('not allowed');
  }
  check(rejectDenied && rejectEffects[0] == 0, 'hitl reject');

  final respondEffects = <int>[0];
  final respondOutput = _runHitl(
    respondEffects,
    (_) => const InterruptDecision(
      action: interruptRespond,
      response: 'human answer',
    ),
  );
  check(respondEffects[0] == 0 && respondOutput.contains('human answer'),
      'hitl respond');

  final unhandledEffects = <int>[0];
  var unhandled = false;
  try {
    _runHitl(unhandledEffects, null);
  } on PraxoError catch (error) {
    unhandled = error.code == 'AGENT_INTERRUPT_UNHANDLED';
  }
  check(unhandled && unhandledEffects[0] == 0, 'hitl unhandled');

  var invalidDecision = false;
  try {
    _runHitl(<int>[0], (_) => const InterruptDecision(action: 'bogus'));
  } on PraxoError catch (error) {
    invalidDecision = error.code == 'AGENT_INTERRUPT_DECISION_INVALID';
  }
  check(invalidDecision, 'hitl invalid decision');

  var editMissingArguments = false;
  try {
    _runHitl(<int>[0], (_) => const InterruptDecision(action: interruptEdit));
  } on PraxoError catch (error) {
    editMissingArguments = error.code == 'AGENT_INTERRUPT_DECISION_INVALID';
  }
  check(editMissingArguments, 'hitl edit requires arguments');

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

  var streamFlag = false;
  final streamDeltas = <String>[];
  final streamAdapter = OpenAICompatibleModel(
    baseUrl: 'https://api.example.com/v1',
    model: 'provider-model',
    streamTransport: (path, payload) {
      check(path == '/chat/completions', 'adapter stream path');
      streamFlag = payload['stream'] == true;
      return 'data: {"choices":[{"delta":{"content":"he"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"llo"}}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"id":"call-1","function":{"name":"ec",'
          '"arguments":"{\\"text\\":"}}]}}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
          '"function":{"name":"ho","arguments":"\\"hi\\"}"}}]}}],'
          '"usage":{"prompt_tokens":4,"completion_tokens":2}}\n\n'
          'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}\n\n'
          'data: [DONE]\n\n';
    },
  );
  final streamResponse = streamAdapter.generateStream(
    adapterRequest,
    streamDeltas.add,
  );
  check(streamFlag, 'adapter stream flag');
  check(streamDeltas.length == 2 &&
      streamDeltas[0] == 'he' &&
      streamDeltas[1] == 'llo', 'adapter stream deltas');
  check(streamResponse.message.content == 'hello', 'adapter stream content');
  check(streamResponse.message.toolCalls.single.id == 'call-1',
      'adapter stream call id');
  check(streamResponse.message.toolCalls.single.name == 'echo',
      'adapter stream call name');
  check(streamResponse.message.toolCalls.single.arguments['text'] == 'hi',
      'adapter stream arguments');
  check(streamResponse.usage.inputTokens == 4 &&
      streamResponse.usage.outputTokens == 2, 'adapter stream usage');
  check(streamResponse.finishReason == 'tool_calls',
      'adapter stream finish');

  final agentStreamAdapter = OpenAICompatibleModel(
    baseUrl: 'https://api.example.com/v1',
    model: 'provider-model',
    streamTransport: (path, payload) =>
        'data: {"choices":[{"delta":{"content":"ok"}}]}\n\n'
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n'
        'data: [DONE]\n\n',
  );
  final agentDeltas = <String>[];
  final agentResult = Agent(AgentOptions(
    agentStreamAdapter,
    onDelta: agentDeltas.add,
  )).run(const Session(id: 's1'), 'go');
  check(agentResult.output == 'ok', 'adapter agent stream output');
  check(agentDeltas.length == 1 && agentDeltas[0] == 'ok',
      'adapter agent stream deltas');

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

  final anthropicEvents = [
    {
      'type': 'message_start',
      'message': {
        'usage': {'input_tokens': 4, 'cache_read_input_tokens': 1}
      }
    },
    {
      'type': 'content_block_start',
      'index': 0,
      'content_block': {'type': 'text', 'text': ''}
    },
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': 'he'}
    },
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': 'llo'}
    },
    {
      'type': 'content_block_start',
      'index': 1,
      'content_block': {
        'type': 'tool_use',
        'id': 'call-1',
        'name': 'echo',
        'input': <String, dynamic>{}
      }
    },
    {
      'type': 'content_block_delta',
      'index': 1,
      'delta': {'type': 'input_json_delta', 'partial_json': '{"text":'}
    },
    {
      'type': 'content_block_delta',
      'index': 1,
      'delta': {'type': 'input_json_delta', 'partial_json': '"hi"}'}
    },
    {
      'type': 'message_delta',
      'delta': {'stop_reason': 'tool_use'},
      'usage': {'output_tokens': 2}
    },
    {'type': 'message_stop'},
  ];
  final anthropicStreamText = anthropicEvents
      .map((event) => 'data: ${Json.stringify(event)}')
      .join('\n\n');
  final anthropicStream = AnthropicModel(
    model: 'claude-test',
    apiKey: 'ak',
    streamTransport: (path, payload) {
      check(path == '/v1/messages', 'anthropic stream path');
      check(payload['stream'] == true, 'anthropic stream flag');
      return anthropicStreamText;
    },
  );
  final anthropicDeltas = <String>[];
  final anthropicStreamResponse = anthropicStream.generateStream(
    providerRequest,
    anthropicDeltas.add,
  );
  check(anthropicDeltas.join() == 'hello', 'anthropic stream deltas');
  check(anthropicStreamResponse.message.content == 'hello',
      'anthropic stream content');
  check(anthropicStreamResponse.message.toolCalls.single.id == 'call-1',
      'anthropic stream call id');
  check(anthropicStreamResponse.message.toolCalls.single.arguments['text'] ==
      'hi', 'anthropic stream args');
  check(anthropicStreamResponse.usage.inputTokens == 4,
      'anthropic stream input tokens');
  check(anthropicStreamResponse.usage.outputTokens == 2,
      'anthropic stream output tokens');
  check(anthropicStreamResponse.usage.cachedTokens == 1,
      'anthropic stream cached');
  check(anthropicStreamResponse.finishReason == 'tool_use',
      'anthropic stream finish');

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

  final geminiStreamed = <String, dynamic>{};
  final geminiStream = GeminiModel(
    model: 'gemini-test',
    apiKey: 'gk',
    streamTransport: (path, payload) {
      geminiStreamed['path'] = path;
      geminiStreamed['payload'] = payload;
      return 'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}\n\n'
          'data: {"candidates":[{"content":{"parts":[{"text":"llo"},'
          '{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},'
          '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,'
          '"candidatesTokenCount":2,"cachedContentTokenCount":1}}';
    },
  );
  final geminiDeltas = <String>[];
  final geminiStreamResponse =
      geminiStream.generateStream(providerRequest, geminiDeltas.add);
  check((geminiStreamed['path'] as String).contains(':streamGenerateContent'),
      'gemini stream path');
  check((geminiStreamed['path'] as String).contains('alt=sse'),
      'gemini stream alt');
  check(geminiDeltas.join() == 'hello', 'gemini stream deltas');
  check(geminiStreamResponse.message.content == 'hello',
      'gemini stream content');
  check(geminiStreamResponse.message.toolCalls.single.name == 'echo',
      'gemini stream call');
  check(geminiStreamResponse.usage.inputTokens == 4, 'gemini stream usage');
  check(geminiStreamResponse.usage.outputTokens == 2, 'gemini stream output');
  check(geminiStreamResponse.usage.cachedTokens == 1, 'gemini stream cached');
  check(geminiStreamResponse.finishReason == 'STOP', 'gemini stream finish');

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

  final fakeMcp = _FakeMcpTransport();
  final mcp = McpClient(transport: fakeMcp);
  await mcp.start();
  check(mcp.protocolVersion == '2024-11-05', 'mcp protocol version');
  check(mcp.serverInfo['name'] == 'fake', 'mcp server info');
  final mcpTools = await mcp.listTools();
  check(
      mcpTools.map((tool) => tool['name']).join(',') == 'add,echo',
      'mcp paginated tools');
  check(await mcp.callTool('echo', {'text': 'hi'}) is Map,
      'mcp structured tool');
  check(await mcp.callTool('text') == 'hello', 'mcp text tool');
  String? mcpError;
  try {
    await mcp.callTool('fail');
  } on PraxoError catch (error) {
    mcpError = error.code;
  }
  check(mcpError == 'MCP_TOOL_ERROR', 'mcp tool error');
  await mcp.close();
  check(fakeMcp.closed, 'mcp closed');

  final httpSeen = <Map<String, dynamic>>[];
  final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  httpServer.listen((request) async {
    if (request.method == 'DELETE') {
      httpSeen.add({'method': 'DELETE', 'headers': <String, String>{}});
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }
    final body = await utf8.decoder.bind(request).join();
    final message = jsonDecode(body) as Map<String, dynamic>;
    httpSeen.add({
      'method': message['method'],
      'headers': {
        'mcp-session-id': request.headers.value('mcp-session-id') ?? '',
        'mcp-protocol-version':
            request.headers.value('mcp-protocol-version') ?? '',
      },
    });
    final id = message['id'];
    final method = message['method'];
    if (method == 'initialize') {
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('mcp-session-id', 'sess-1');
      request.response.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'protocolVersion': '2025-03-26',
          'capabilities': <String, dynamic>{},
          'serverInfo': {'name': 'fake-http', 'version': '1'},
        },
      }));
    } else if ((method as String).startsWith('notifications/')) {
      request.response.statusCode = 202;
    } else if (method == 'tools/list') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'tools': [
            {
              'name': 'echo',
              'description': 'Echo input',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'text': {'type': 'string'},
                },
                'required': ['text'],
              },
            },
          ],
        },
      }));
    } else if (method == 'tools/call') {
      final payload = jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'content': [
            {'type': 'text', 'text': 'sse-ok'},
          ],
        },
      });
      request.response.headers.contentType =
          ContentType('text', 'event-stream');
      request.response.write('event: message\ndata: $payload\n\n');
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
          jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': <String, dynamic>{}}));
    }
    await request.response.close();
  });

  final httpTransport = McpStreamableHttpTransport(
    endpoint: 'http://127.0.0.1:${httpServer.port}/mcp',
  );
  final httpMcp = McpClient(
    transport: httpTransport,
    requestedProtocolVersion: '2025-03-26',
  );
  await httpMcp.start();
  check(httpMcp.protocolVersion == '2025-03-26', 'http mcp protocol version');
  final httpTools = await httpMcp.listTools();
  check(httpTools.map((tool) => tool['name']).join(',') == 'echo',
      'http mcp tools');
  check(await httpMcp.callTool('echo', {'text': 'hi'}) == 'sse-ok',
      'http mcp sse call');
  await httpMcp.close();
  final listed = httpSeen.where((item) => item['method'] == 'tools/list');
  check(
      listed.any((item) =>
          (item['headers'] as Map)['mcp-session-id'] == 'sess-1'),
      'http mcp session header');
  check(
      httpSeen.any((item) =>
          (item['headers'] as Map)['mcp-protocol-version'] == '2025-03-26'),
      'http mcp protocol header');
  check(httpSeen.any((item) => item['method'] == 'DELETE'), 'http mcp delete');
  await httpServer.close(force: true);

  String? httpRejected;
  try {
    McpStreamableHttpTransport(endpoint: 'http://example.com/mcp');
  } on PraxoError catch (error) {
    httpRejected = error.code;
  }
  check(httpRejected == 'MCP_TRANSPORT', 'http mcp https required');

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

  String? otelBody;
  final otelTransport = (String method, String url, String body,
      Map<String, String> headers) {
    check(method == 'POST', 'otel method');
    check(url == 'https://otel.test/v1/traces', 'otel url');
    check(headers['content-type'] == 'application/json', 'otel content type');
    otelBody = body;
    return const OtelResponse(200, '');
  };
  final otelSink = OtelSink(
    endpoint: 'https://otel.test/v1/traces',
    allowedDataKeys: const ['name'],
    transport: otelTransport,
    clock: () => 1794294000000000000,
  );
  otelSink.emit(const Event(
    type: 'tool.call',
    sessionId: 's1',
    runId: 'run-123',
    data: {'name': 'echo', 'secret': 'hidden'},
  ));
  final otel = Json.parse(otelBody!) as Map<String, dynamic>;
  final resourceSpans = otel['resourceSpans'] as List;
  final resource = resourceSpans.first as Map<String, dynamic>;
  final scopeSpans = resource['scopeSpans'] as List;
  final scope = scopeSpans.first as Map<String, dynamic>;
  final span = (scope['spans'] as List).first as Map<String, dynamic>;
  check(span['name'] == 'praxo.tool.call', 'otel span name');
  check((span['traceId'] as String).length == 32, 'otel trace id');
  check((span['spanId'] as String).length == 16, 'otel span id');
  final attributeKeys = (span['attributes'] as List)
      .map((item) => (item as Map<String, dynamic>)['key'])
      .toSet();
  check(attributeKeys.contains('praxo.event.data.name'), 'otel allowed data');
  check(!attributeKeys.contains('praxo.event.data.secret'), 'otel hidden data');
  final otelFailure = OtelSink(
    endpoint: 'https://otel.test/v1/traces',
    transport: (String method, String url, String body,
            Map<String, String> headers) =>
        const OtelResponse(503, 'unavailable'),
  );
  Object? otelError;
  try {
    otelFailure.emit(const Event(type: 'tool.call', sessionId: 's1'));
  } on PraxoError catch (error) {
    otelError = error;
  }
  check((otelError as PraxoError?)?.code == 'OTEL_HTTP', 'otel failure code');

  final retriever = FuncRetriever((String query, int limit) async => [
        Document(id: 'doc-1', content: '$query:$limit'),
      ]);
  final documents =
      await retrieveDocuments(retriever.retrieve, 'hello', 3);
  check(documents.length == 1, 'retriever count');
  check(documents.first.content == 'hello:3', 'retriever query');
  Object? retrieverError;
  try {
    await retrieveDocuments(retriever.retrieve, 'hello', -1);
  } on PraxoError catch (error) {
    retrieverError = error;
  }
  check((retrieverError as PraxoError?)?.code == 'RETRIEVER_INVALID',
      'retriever invalid limit');

  final manager = SubagentManager((SubagentRequest request) async =>
      SubagentResult(taskId: 'task-1', agentId: request.agentId, output: 'done'));
  final task = await manager.run(const SubagentRequest(
    parentSessionId: 'parent',
    agentId: 'child',
    prompt: 'look up',
    mode: 'fork',
  ));
  check(task.status == 'completed', 'delegate completed');
  check(task.mode == 'fork', 'delegate mode');
  check(task.output == 'done', 'delegate output');
  final failingManager =
      SubagentManager((SubagentRequest request) async =>
          throw const PraxoError('BOOM', 'boom'));
  final failed = await failingManager.run(const SubagentRequest(
    parentSessionId: 'parent',
    agentId: 'child',
    prompt: 'look up',
  ));
  check(failed.status == 'failed', 'delegate failed status');
  check(failed.error == 'BOOM', 'delegate failed code');
  Object? delegateError;
  try {
    await manager.run(const SubagentRequest(
      parentSessionId: '',
      agentId: 'child',
      prompt: 'look up',
    ));
  } on PraxoError catch (error) {
    delegateError = error;
  }
  check((delegateError as PraxoError?)?.code == 'SUBAGENT_INVALID',
      'delegate invalid');

  final fixture = File('test/fixtures/process_plugin.py').absolute.path;
  final processHost = PluginProcessHost(PluginProcessConfig(
    pluginId: 'com.example.echo',
    path: Platform.environment['PYTHON'] ?? 'python',
    args: [fixture],
    invokeTimeout: const Duration(seconds: 2),
    gracePeriod: const Duration(seconds: 2),
  ));
  await processHost.start();
  check(processHost.isActive, 'plugin process active');
  final pluginPayload = utf8.encode('{"text":"hi"}');
  final echoed = await processHost.invoke('tool.provider', 'echo', pluginPayload);
  check(utf8.decode(echoed) == '{"text":"hi"}', 'plugin process echo');
  Object? pluginDenied;
  try {
    await processHost.invoke('tool.provider', 'denied');
  } on PluginCallException catch (error) {
    pluginDenied = error;
  }
  check((pluginDenied as PluginCallException?)?.code == 'CAPABILITY_DENIED',
      'plugin process denied');
  await processHost.stop();
  check(!processHost.isActive, 'plugin process stopped');

  final idleHost = PluginProcessHost(PluginProcessConfig(
    pluginId: 'com.example.echo',
    path: Platform.environment['PYTHON'] ?? 'python',
    args: [fixture],
  ));
  Object? idleError;
  try {
    await idleHost.invoke('tool.provider', 'echo');
  } on PluginCallException catch (error) {
    idleError = error;
  }
  check((idleError as PluginCallException?)?.code == 'NOT_ACTIVE',
      'plugin process not active');

  final slowHost = PluginProcessHost(PluginProcessConfig(
    pluginId: 'com.example.echo',
    path: Platform.environment['PYTHON'] ?? 'python',
    args: [fixture],
    invokeTimeout: const Duration(milliseconds: 200),
  ));
  await slowHost.start();
  Object? timeoutError;
  try {
    await slowHost.invoke('tool.provider', 'block');
  } on PluginCallException catch (error) {
    timeoutError = error;
  }
  check((timeoutError as PluginCallException?)?.code == 'TIMEOUT',
      'plugin process timeout');
  await slowHost.stop();

  stdout.writeln('dart core tests passed');
}

class RecordingSink implements EventSink {
  final List<String> types = [];

  @override
  void emit(Event event) => types.add(event.type);
}

Decision _allowPublicNote(Action action) {
  if (action.kind == 'model.generate') {
    return const Decision(allowed: true);
  }
  if (action.kind == 'tool.invoke') {
    return Decision(
      allowed: action.toolName == 'write_note' &&
          action.arguments?['visibility'] == 'public',
      reason: 'only public notes are permitted',
    );
  }
  return const Decision(allowed: false, reason: 'unsupported action');
}

String _runHitl(
  List<int> effects,
  InterruptDecision Function(Interrupt)? decision, {
  bool Function(Interrupt)? approval,
  List<String> interruptOn = const ['write_note'],
  EventSink? events,
}) {
  var invocations = 0;
  final registry = Registry()
    ..register(FuncTool('write_note', 'Write a note', (arguments) {
      invocations += 1;
      return 'written';
    }));
  final options = AgentOptions(
    _HitlModel(),
    tools: registry,
    events: events,
    maxSteps: 3,
    allowedTools: const ['write_note'],
    policy: _allowPublicNote,
    interruptOn: interruptOn,
    onInterruptDecision: decision,
    onInterrupt: approval,
  );
  try {
    return runAgent(options, const Session(id: 'hitl'), 'Write a note.').output;
  } finally {
    effects[0] = invocations;
  }
}

class _HitlModel implements Model {
  var calls = 0;

  @override
  Response generate(Request request) {
    calls += 1;
    if (calls == 1) {
      return Response(
        message: Message.assistant('', [
          const ToolCall(
            id: 'write-1',
            name: 'write_note',
            arguments: {'text': 'hello', 'visibility': 'public'},
          ),
        ]),
      );
    }
    final last = request.messages.last;
    return Response(
      message: Message.assistant(
        last.role == roleTool ? (last.content ?? '') : 'done',
      ),
    );
  }
}

class _FakeMcpTransport implements McpTransport {
  bool closed = false;
  final List<String> notifications = [];

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  ) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': '2024-11-05',
          'serverInfo': {'name': 'fake'},
        };
      case 'tools/list':
        if (params['cursor'] != null) {
          return {
            'tools': [
              {'name': 'echo'},
            ],
          };
        }
        return {
          'tools': [
            {'name': 'add'},
          ],
          'nextCursor': 'next',
        };
      case 'tools/call':
        switch (params['name']) {
          case 'echo':
            return {
              'structuredContent': {'ok': true},
            };
          case 'text':
            return {
              'content': [
                {'type': 'text', 'text': 'hello'},
              ],
            };
          case 'fail':
            return {'isError': true};
        }
    }
    return {};
  }

  @override
  void notify(String method, Map<String, dynamic> params) {
    notifications.add(method);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _TestModel implements Model {
  final List<Message> messages;
  var next = 0;

  _TestModel(this.messages);

  @override
  Response generate(Request request) => Response(message: messages[next++]);
}
