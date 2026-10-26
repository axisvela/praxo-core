program contract_tests
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_unicode
  use praxo_json
  use praxo_checkpoint
  use praxo_toolcall
  use praxo_policy
  use praxo_plugin
  use praxo_pattern
  use praxo_schema
  use praxo_interfaces
  use praxo_middleware
  use praxo_agent
  use praxo_runtime
  use test_doubles
  implicit none
  type(json_document) :: a, b
  type(checkpoint_allowlist) :: allowlist
  type(sdk_error) :: error
  type(parsed_tool_call) :: parsed
  type(path_checker) :: checker
  type(decision) :: verdict
  type(plugin_manifest) :: manifest
  type(validation_error), allocatable :: errors(:)
  type(call_limit), target :: limits
  type(tool_selection), target :: selection
  type(scripted_model), target :: primary, secondary
  type(fallback_model) :: fallback
  type(structured_model) :: structured
  type(request) :: req
  type(response) :: res
  type(registry), target :: tools
  type(echo_tool) :: echo
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(recording_sink), target :: sink
  type(memory_store) :: memory
  type(memory_record), allocatable :: records(:)
  character(:), allocatable :: text, envelope, value
  character(*), parameter :: base = '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",'// &
    '"kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},'// &
    '"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}'
  integer, target :: invocations
  integer :: checks = 0
  logical :: matched

  call parse_json('"a"', a, error)
  call parse_json('"a "', b, error)
  call check(.not. json_equal(a, 1, b, 1), 'JSON trailing spaces are significant')
  call parse_json('{"key ":1}', a, error)
  call check(json_get(a, 1, 'key') == 0, 'JSON property names are exact')
  call parse_json('{"x":1,"x":2}', a, error)
  call parse_json('{"x":2}', b, error)
  call check(json_equal(a, 1, a, 1) .and. json_equal(a, 1, b, 1), 'duplicate last value equality')
  call parse_json('1.00e2', a, error)
  call parse_json('100', b, error)
  call check(json_equal(a, 1, b, 1), 'decimal equality without binary rounding')
  call parse_json('9007199254740993', a, error)
  call parse_json('9007199254740992', b, error)
  call check(.not. json_equal(a, 1, b, 1), 'large integer equality is exact')
  a%nodes(1)%text = '1,true'
  text = encode_json(a, 1, error)
  call check(error%failed() .and. len(text) == 0, 'numeric serialization cannot inject JSON')

  call allowlist%register('spec."name', error)
  envelope = allowlist%marshal('spec."name', '{"x":[1,true]}', error)
  call check(.not. error%failed(), 'escaped checkpoint type name')
  value = allowlist%unmarshal(envelope, error)
  call check(.not. error%failed() .and. value == '{"x":[1,true]}', 'checkpoint roundtrip')
  text = allowlist%marshal('spec."name ', '{}', error)
  call check(string_value(error%code) == 'CHECKPOINT_TYPE_NOT_ALLOWED', 'checkpoint type trailing space denied')
  text = allowlist%unmarshal('{"type":"spec.\"name"}', error)
  call check(error%failed(), 'checkpoint missing data rejected')
  text = allowlist%marshal('spec."name', '{}{}', error)
  call check(error%failed(), 'checkpoint malformed payload rejected')
  text = allowlist%marshal('spec."name', '"'//repeat('x', 262140)//'"', error)
  call check(string_value(error%code) == 'JSON_CAPACITY' .and. len(text) == 0, 'checkpoint envelope capacity')
  call allowlist%register('', error)
  call check(error%failed(), 'empty checkpoint type rejected')

  text = parse_input_json('[]', error)
  call check(error%failed(), 'tool input must be an object')
  parsed = parse_tool_call('<echo.run>{"nested":{"x":"}"}}</echo.run>')
  call check(parsed%found, 'nested tool argument object')
  parsed = parse_tool_call('<tool_call name="echo">not json</tool_call>')
  call check(.not. parsed%found, 'invalid tool markup cannot invoke')
  call check(strip_markup('hello<b>world</b>') == 'hello<b>world</b>', 'non-tool markup preserved')
  call check(strip_markup('a<tool_call name="x">{}') == 'a', 'unclosed tool markup removed')

  matched = match_pattern('^[a-z]+[0-9]?$', 'abc2', error)
  call check(matched .and. .not. error%failed(), 'generic character classes and quantifiers')
  matched = match_pattern('^a*$', '', error)
  call check(matched .and. .not. error%failed(), 'empty repeated pattern')
  matched = match_pattern('^a+$', '', error)
  call check(.not. matched .and. .not. error%failed(), 'required repeated pattern')
  matched = match_pattern('b.c', 'xxbzcxx', error)
  call check(matched, 'unanchored pattern search')
  matched = match_pattern('a|b', 'a', error)
  call check(error%failed(), 'unsupported regex fails explicitly')
  matched = match_pattern(achar(92), '', error)
  call check(error%failed(), 'trailing pattern escape rejected')
  call validate_schema('{"type":"array","items":{"type":"integer"}}', '[1,"x"]', errors, error)
  call check(.not. error%failed() .and. size(errors) == 1, 'nested schema validation')
  call check(errors(1)%path == '$[1]', 'array error path')
  call validate_schema('{"type":"number","enum":[1]}', '1.0', errors, error)
  call check(.not. error%failed() .and. size(errors) == 0, 'numeric enum semantic equality')
  call validate_schema('{"type":"string","enum":["x"]}', '"x "', errors, error)
  call check(size(errors) == 1, 'string enum preserves trailing spaces')

  call parse_manifest(base, manifest, error)
  call check(.not. error%failed(), 'minimal manifest')
  call parse_manifest(replaced(base, 'jsonrpc-2', 'jsonrpc-2 '), manifest, error)
  call check(error%failed(), 'protocol trailing space rejected')
  call parse_manifest(replaced(base, '"type":"process"', '"type":"process "'), manifest, error)
  call check(error%failed(), 'entrypoint type trailing space rejected')
  call parse_manifest(replaced(base, '"limits":{}', '"limits":{"memoryMB":-1}'), manifest, error)
  call check(error%failed(), 'negative plugin limits')
  call parse_manifest(replaced(base, '"health":{}', '"health":{"intervalMs":1}'), manifest, error)
  call check(error%failed(), 'health interval requires method')
  call parse_manifest(replaced(base, '"permissions":{}', '"permissions":{"env":["BAD-NAME"]}'), manifest, error)
  call check(error%failed(), 'invalid environment permission')
  call parse_manifest(replaced(base, '"command":"echo"', '"command":"echo","extra":1'), manifest, error)
  call check(error%failed(), 'unknown nested manifest field')
  call parse_manifest(replaced(base, '"version":"1.0.0"', '"version":"01.0.0"'), manifest, error)
  call check(error%failed(), 'invalid version')

  checker%grants = [path_grant('root', 'readwrite')]
  verdict = checker%check('root/a', 'read ', error)
  call check(error%failed(), 'invalid access trailing space')
  verdict = checker%check('root/../../outside', 'read', error)
  call check(.not. verdict%allowed, 'nested traversal denied')
  verdict = checker%check('root-evil/a', 'read', error)
  call check(.not. verdict%allowed, 'sibling prefix denied')
  call check(normalize_path('root/.. /a') == 'root/.. /a', 'path spaces preserved')
  call check(normalize_path('C:relative') == '', 'drive-relative path rejected')
  call check(same_string(normalize_path(' '), ' '), 'space-only path component preserved')

  limits%model_limit = 1
  limits%tool_limit = 1
  call limits%check('a', 'model', error)
  call limits%check('b', 'model', error)
  call check(.not. error%failed(), 'call count isolation by run')
  call limits%check('a', 'model', error)
  call check(string_value(error%code) == 'AGENT_MODEL_CALL_LIMIT', 'model limit')
  call limits%check('a', 'tool', error)
  call limits%check('a', 'tool', error)
  call check(string_value(error%code) == 'AGENT_TOOL_CALL_LIMIT', 'tool limit independent of model')
  call limits%clear()
  call limits%check('a', 'model', error)
  call check(.not. error%failed(), 'limit state can be cleared')
  call limits%check('a', 'other', error)
  call check(error%failed(), 'unknown limit kind rejected')
  selection%selected = [string_item('echo')]
  call selection%check('echo ', error)
  call check(error%failed(), 'selected tool names are exact')
  call check(redact_email('a@b.com and c@d.com') == &
    '[REDACTED:email] and [REDACTED:email]', 'multiple email redaction')
  text = redact_json_email('{"x":[{"mail":"a@b.com"}],"n":3}', error)
  call check(.not. error%failed() .and. index(text, 'a@b.com') == 0, 'deep JSON redaction')

  allocate(primary%script(1), secondary%script(1))
  primary%script(1)%message = text_message('assistant', 'primary')
  secondary%script(1)%message = text_message('assistant', 'secondary')
  fallback%primary => primary
  fallback%fallback => secondary
  call fallback%generate(req, res, error)
  call check(.not. error%failed() .and. secondary%calls == 0, 'fallback is lazy on success')
  primary%calls = 0
  primary%script(1)%message = text_message('assistant', '{"value":"bad"}')
  structured%provider => primary
  structured%schema = '{"type":"object","properties":{"value":{"type":"integer"}}}'
  structured%max_repairs = 1
  structured%repair => repair_fixture
  repair_content = '{"value":2}'
  call structured%generate(req, res, error)
  call check(.not. error%failed() .and. res%message%content == repair_content, 'structured model repair')
  call check(repair_attempt == 1 .and. repair_error_count == 1 .and. &
    repair_previous == '{"value":"bad"}', 'repair callback receives errors and attempt')

  primary%calls = 0
  primary%script(1)%message = text_message('assistant', '')
  primary%script(1)%message%tool_calls = [tool_call('c1', 'echo', '{}'), tool_call('c2', 'echo', '{}')]
  invocations = 0
  echo%spec = tool_spec('echo', 'echo')
  echo%calls => invocations
  call tools%register(echo, error)
  call check(tools%has('echo') .and. .not. tools%has('echo '), 'registry membership is exact')
  call tools%invoke('echo ', '{}', text, error)
  call check(string_value(error%code) == 'TOOL_NOT_FOUND', 'registry tool names are exact')
  call limits%clear()
  options%provider => primary
  options%tools => tools
  options%limits => limits
  options%events => sink
  state%id = 's1'
  call run_agent(options, state, 'hello', 'native-limit', result, error)
  call check(string_value(error%code) == 'AGENT_TOOL_CALL_LIMIT' .and. invocations == 1, 'agent tool limit hook')
  call check(sink%items(size(sink%items))%kind == 'run.failed', 'limit failure terminal event')
  primary%calls = 0
  nullify(options%limits)
  options%selection => selection
  primary%script(1)%message%tool_calls(1)%name = 'other'
  call run_agent(options, state, 'hello', 'native-selection', result, error)
  call check(string_value(error%code) == 'AGENT_TOOL_NOT_SELECTED', 'agent selection hook')
  call check(size(primary%last_request%tools) == 1, 'agent advertised selection')
  primary%calls = 0
  primary%script(1)%message = text_message('assistant', 'done')
  options%redact_emails = .true.
  call run_agent(options, state, 'email a@b.com', 'native-pii', result, error)
  call check(primary%last_request%messages(1)%content == 'email [REDACTED:email]', 'agent email hook')
  allocate(state%messages(1))
  state%messages(1) = text_message('assistant', '')
  state%messages(1)%tool_calls = [tool_call('old', 'echo', '{"email":"a\u0040b.com"}')]
  primary%calls = 0
  call run_agent(options, state, 'hello', 'native-pii-arguments', result, error)
  call check(primary%last_request%messages(1)%tool_calls(1)%arguments == &
    '{"email":"[REDACTED:email]"}', 'model-bound tool arguments are redacted after JSON decoding')
  call memory%put('s1 ', memory_record('m1', 'event', 'x', '2026-01-01T00:00:00Z'))
  records = memory%search('s1', '', 0)
  call check(size(records) == 0, 'memory session names are exact')
  print '(a,i0,a)', 'PASS: ', checks, ' native Fortran contract assertions'
contains
  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    print '(a)', 'FAIL: '//label
    error stop 1
  end subroutine

  function replaced(raw, from, to) result(output)
    character(*), intent(in) :: raw, from, to
    character(:), allocatable :: output
    integer :: start
    start = index(raw, from)
    if (start == 0) error stop 'missing test replacement'
    output = raw(:start - 1)//to//raw(start + len(from):)
  end function
end program
