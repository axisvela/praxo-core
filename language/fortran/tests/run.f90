program core_tests
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_interfaces
  use praxo_agent
  use praxo_runtime
  use praxo_context
  use praxo_stream
  use praxo_sse, only: parse_sse_stream
  use praxo_middleware, only: call_limit
  use praxo_openai
  use test_doubles
  implicit none
  type(scripted_model), target :: provider
  type(cancel_model), target :: cancel_provider
  type(cancel_tool) :: canceler
  type(echo_tool) :: echo, other
  type(registry), target :: tools
  type(recording_sink), target :: sink, second
  type(deny_policy), target :: gate
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error
  type(filter_sink) :: filter
  type(multi_sink) :: multi
  type(memory_store) :: store
  type(memory_record), allocatable :: records(:)
  type(tool_spec), allocatable :: specs(:)
  type(sdk_error) :: sse_error
  character(:), allocatable :: sse_content
  type(event) :: item
  type(context_budget) :: budget
  type(message), allocatable :: messages(:), compacted(:)
  logical :: ok
  character(:), allocatable :: output
  integer, target :: invocations, other_invocations
  integer :: failures = 0, checks = 0, i
  character(:), allocatable :: hitl_action, hitl_arguments, hitl_response
  type(openai_compatible) :: adapter
  type(request) :: adapter_request
  type(response) :: adapter_response
  character(:), allocatable :: captured_url, captured_payload, captured_key
  character(:), allocatable :: adapter_text

  call reset()
  call run()
  call check(.not. error%failed(), 'direct answer succeeds')
  call check(result%output == 'hello' .and. result%steps == 1, 'direct answer result')
  call check(size(sink%items) == 2, 'direct answer event count')
  call check(sink%items(1)%kind == 'run.started' .and. &
    sink%items(2)%kind == 'run.completed', 'direct answer event ordering')
  call check(sink%items(1)%session_id == 's1' .and. &
    sink%items(1)%run_id == 'test-run', 'event identity')
  call check(size(state%messages) == 0, 'caller history is unchanged')

  call reset()
  call tool_script()
  options%system_prompt = 'be terse'
  call run()
  call check(.not. error%failed() .and. result%output == 'done', 'tool then answer')
  call check(result%steps == 2 .and. invocations == 1, 'tool execution count')
  call check(size(provider%last_request%messages) == 4, 'full model request history')
  call check(provider%last_request%messages(1)%role == 'system', 'system prompt')
  call check(provider%last_request%messages(3)%tool_calls(1)%id == 'c1', 'assistant call history')
  call check(provider%last_request%messages(4)%content == '{"text":"hi"}' .and. &
    provider%last_request%messages(4)%tool_call_id == 'c1', 'tool result history')
  call check(size(provider%last_request%tools) == 1, 'tool specifications passed to model')
  call check(size(sink%items) == 3 .and. sink%items(2)%kind == 'tool.call', 'tool events')

  call reset()
  call tool_script()
  options%max_steps = 1
  call run()
  call check_error('AGENT_MAX_STEPS', 'step budget')
  call check(invocations == 1 .and. provider%calls == 1, 'no extra call after step budget')

  call reset()
  options%max_tokens = 5
  provider%script(1)%usage%output_tokens = 10
  call run()
  call check_error('AGENT_MAX_TOKENS', 'token budget')
  call check(result%output == '' .and. invocations == 0, 'budget failure cannot leak answer')

  call reset()
  call tool_script()
  options%max_tokens = 5
  provider%script(1)%usage%input_tokens = 3
  provider%script(2)%usage%output_tokens = 3
  call run()
  call check_error('AGENT_MAX_TOKENS', 'cumulative token budget')

  call reset()
  gate%denied_kind = 'model.generate'
  options%gate => gate
  call run()
  call check_error('AGENT_POLICY_DENIED', 'model policy denial')
  call check(provider%calls == 0, 'model denial occurs before generation')

  call reset()
  call tool_script()
  gate%denied_kind = 'tool.invoke'
  options%gate => gate
  call run()
  call check_error('AGENT_POLICY_DENIED', 'tool policy denial')
  call check(invocations == 0 .and. size(sink%items) == 2, 'tool denial before invocation and event')


  call reset()
  call tool_script()
  hook_mutate_arguments = .true.
  allocate(options%middleware(1))
  options%middleware(1)%before_tool => hook_before_tool
  call run()
  call check(.not. error%failed() .and. result%output == 'done', 'middleware final arguments result')
  call check(hook_before_tool_calls == 1, 'middleware final arguments called')
  call check(provider%last_request%messages(3)%content == '{"text":"mutated"}', &
    'middleware final arguments effect')

  call reset()
  call tool_script()
  other%spec = tool_spec('other', 'Other')
  other%calls => other_invocations
  other%fail = .false.
  call tools%register(other, error)
  allocate(character(8) :: options%allowed_tools(2))
  options%allowed_tools(1) = 'echo'
  options%allowed_tools(2) = 'other'
  hook_rename_tool = .true.
  hook_renamed_tool = 'other'
  allocate(options%middleware(1))
  options%middleware(1)%before_tool => hook_before_tool
  call run()
  call check(.not. error%failed() .and. other_invocations == 1 .and. invocations == 0, &
    'middleware final name uses final tool')

  call reset()
  call tool_script()
  gate%denied_kind = 'none'
  options%gate => gate
  allocate(options%middleware(1))
  options%middleware(1)%before_tool => hook_before_tool
  call run()
  call check(.not. error%failed() .and. gate%tool_calls == 1, &
    'middleware unchanged single authorization')

  call reset()
  call tool_script()
  gate%denied_kind = 'tool.invoke'
  options%gate => gate
  allocate(options%middleware(1))
  options%middleware(1)%before_tool => hook_before_tool
  call run()
  call check_error('AGENT_POLICY_DENIED', 'middleware initial denial')
  call check(hook_before_tool_calls == 0 .and. invocations == 0, &
    'middleware initial denial precedes middleware and effect')

  call reset()
  hook_fail_before_run = .true.
  allocate(options%middleware(2))
  options%middleware(1)%before_run => hook_before_run_record
  options%middleware(1)%after_run => hook_after_run_record
  options%middleware(2)%before_run => hook_before_run_fail
  options%middleware(2)%after_run => hook_after_run_record
  call run()
  call check(string_value(error%code) == 'STARTUP_FAILED', 'middleware startup failure')
  call check(hook_before_run_calls == 2 .and. hook_after_run_calls == 2, &
    'middleware startup cleanup')
  call check(.not. allocated(sink%items), 'middleware startup emits no run events')

  call reset()
  provider%fail_at = 1
  hook_fail_after_run = .true.
  allocate(options%middleware(2))
  options%middleware(1)%after_run => hook_after_run_fail
  options%middleware(2)%after_run => hook_after_run_record
  call run()
  call check_error('TEST_MODEL_FAILURE', 'middleware after-run preserves run error')
  call check(hook_after_run_calls == 2, 'middleware after-run continues')

  call reset()
  hook_fail_after_run = .true.
  allocate(options%middleware(2))
  options%middleware(1)%after_run => hook_after_run_fail
  options%middleware(2)%after_run => hook_after_run_record
  call run()
  call check_error('CLEANUP_FAILED', 'middleware cleanup fail closed')
  call check(hook_after_run_calls == 2, 'middleware cleanup continues')

  call reset()
  provider%fail_at = 1
  call run()
  call check_error('TEST_MODEL_FAILURE', 'model error propagation')

  call reset()
  call tool_script()
  echo%fail = .true.
  call tools%register(echo, error)
  call run()
  call check_error('TEST_TOOL_FAILURE', 'tool error propagation')

  call reset()
  call tool_script()
  nullify(options%tools)
  call run()
  call check_error('TOOL_NOT_FOUND', 'missing tool registry')

  call reset()
  call tool_script()
  provider%script(1)%message%tool_calls(1)%name = 'unknown'
  call run()
  call check_error('TOOL_NOT_FOUND', 'unregistered tool')

  call reset()
  provider%script(1)%usage%input_tokens = -1
  call run()
  call check_error('INVALID_REQUEST', 'negative usage rejected')

  call reset()
  call tool_script()
  provider%script(1)%usage%input_tokens = huge(0_int64)
  provider%script(2)%usage%input_tokens = 1
  call run()
  call check_error('AGENT_MAX_TOKENS', 'integer overflow rejected')

  call reset()
  options%max_steps = 0
  deallocate(provider%script)
  allocate(provider%script(8))
  do i = 1, 8
    provider%script(i)%message = text_message('assistant', '')
    provider%script(i)%message%tool_calls = [tool_call('c1', 'echo', '{}')]
  end do
  call run()
  call check_error('AGENT_MAX_STEPS', 'default step budget')
  call check(provider%calls == 8 .and. invocations == 8, 'default eight steps')
  call check(options%max_steps == 0, 'options are immutable')

  call reset()
  nullify(options%provider)
  call run()
  call check_error('INVALID_REQUEST', 'missing model rejected', terminal=.false.)

  call reset()
  nullify(options%events, options%tools, options%gate)
  call run()
  call check(.not. error%failed(), 'optional callbacks absent')

  call reset()
  options%context%max_tokens = 2
  options%system_prompt = 'cannot fit'
  call run()
  call check_error('AGENT_CONTEXT_BUDGET', 'agent context enforcement')
  call check(provider%calls == 0, 'context checked before model invocation')

  call reset()
  echo%spec%name = 'z'
  call tools%register(echo, error)
  specs = tools%specs()
  call check(size(specs) == 2 .and. specs(1)%name == 'echo' .and. specs(2)%name == 'z', 'sorted specs')
  call tools%register(echo, error)
  specs = tools%specs()
  call check(size(specs) == 2, 'duplicate registration replaces')
  echo%spec%name = ''
  call tools%register(echo, error)
  call check(string_value(error%code) == 'INVALID_REQUEST', 'empty tool name rejected')
  call tools%invoke('missing', '{}', output, error)
  call check(string_value(error%code) == 'TOOL_NOT_FOUND', 'registry fails closed')

  sink = recording_sink()
  second = recording_sink()
  item = event('run.started', 's1', 'r1', '', '')
  filter%target => sink
  filter%kinds = [character(32) :: 'tool.call']
  call filter%emit(item)
  call check(.not. allocated(sink%items), 'filter rejects unmatched event')
  item%kind = 'tool.call'
  call filter%emit(item)
  call check(size(sink%items) == 1, 'filter forwards matched event')
  call multi%emit(item)
  call multi%add(sink)
  call multi%add(second)
  call multi%emit(item)
  call check(size(sink%items) == 2 .and. size(second%items) == 1, 'multi sink delivers to both')
  call check(sink%items(2)%run_id == 'r1', 'sink preserves event payload')

  call store%put('s1', memory_record('m1', 'event', 'Alpha', '2026-01-01T00:00:00Z'))
  call store%put('s2', memory_record('other', 'event', 'alpha', '2026-01-04T00:00:00Z'))
  call store%put('s1', memory_record('m2', 'event', 'ALPHABET', '2026-01-03T00:00:00Z'))
  records = store%search('s1', 'alpha', 0)
  call check(size(records) == 2, 'memory session isolation and case insensitive query')
  call check(records(1)%id == 'm2' .and. records(2)%id == 'm1', 'memory newest first')
  records = store%search('s1', '', 1)
  call check(size(records) == 1 .and. records(1)%id == 'm2', 'memory limit after ordering')
  records = store%search('s1', 'not found', 0)
  call check(size(records) == 0, 'memory no matches')

  allocate(messages(11))
  messages(1) = text_message('system', 'sys')
  do i = 2, 11
    messages(i) = text_message('user', 'message '//achar(iachar('0') + i - 2))
  end do
  call check(estimate_tokens(messages(:3)) == 16, 'context token estimation')
  budget = context_budget(30_int64, 2)
  call budget%compact(messages, compacted, ok)
  call check(ok .and. size(compacted) == 3, 'context keeps recent messages')
  call check(estimate_tokens(compacted) == 25, 'compacted token estimate')
  call check(compacted(2)%content == '[context compacted: 8 older messages omitted]' .and. &
    compacted(3)%content == 'message 9', 'compaction marker and retained message')
  call check(size(messages) == 11, 'context does not mutate input')
  messages = [text_message('system', repeat('x', 100))]
  budget = context_budget(5_int64, 0)
  call budget%compact(messages, compacted, ok)
  call check(ok .and. compacted(1)%content == 'xxxx', 'oversized system prompt truncated')
  budget%max_tokens = 2
  call budget%compact(messages, compacted, ok)
  call check(.not. ok .and. size(compacted) == 0, 'impossible context budget fails closed')
  budget%max_tokens = 0
  call budget%compact(messages, compacted, ok)
  call check(ok .and. compacted(1)%content == repeat('x', 100), 'disabled context budget')

  block
    type(stream_part) :: part
    part%run_id = 'run-1'
    part%session_id = 'session-1'
    part%kind = 'values'
    part%step = 3
    part%data = '{"value":1}'
    part%at = '2026-10-30T00:00:00Z'
    call check(part%run_id == 'run-1' .and. part%session_id == 'session-1', 'stream part identity')
    call check(part%kind == 'values' .and. part%step == 3, 'stream part kind and step')
    call check(part%data == '{"value":1}' .and. part%at == '2026-10-30T00:00:00Z', 'stream part data and time')
  end block

  call reset()
  hook_cancelled = .false.
  options%provider => cancel_provider
  options%cancelled => hook_cancel
  call run()
  call check(string_value(error%code) == 'AGENT_CANCELLED', 'model cancellation')
  call check(size(sink%items) == 2 .and. sink%items(2)%kind == 'run.failed', &
    'model cancellation events')

  call reset()
  call tool_script()
  provider%script(1)%message%tool_calls(1)%name = 'cancel'
  canceler%spec = tool_spec('cancel', 'Cancel')
  call tools%register(canceler, error)
  hook_cancelled = .false.
  options%cancelled => hook_cancel
  call run()
  call check(string_value(error%code) == 'AGENT_CANCELLED', 'tool cancellation')
  call check(size(sink%items) == 3 .and. sink%items(2)%kind == 'tool.call' .and. &
    sink%items(3)%kind == 'run.failed', 'tool cancellation events')

  call reset()
  hook_fail_stream = .true.
  options%on_stream => hook_stream
  call run()
  call check(string_value(error%code) == 'STREAM_ERROR', 'stream failure')
  call check(hook_stream_count == 2, 'stream parts')
  call check(size(sink%items) == 2 .and. sink%items(2)%kind == 'run.failed', &
    'stream failure events')

  call reset()
  deallocate(provider%script)
  allocate(provider%script(2))
  provider%script(1)%message = text_message('assistant', '')
  provider%script(1)%message%tool_calls = [ &
    tool_call('c1', 'echo', '{"x":1}'), &
    tool_call('c2', 'echo', '{"x":2}')]
  provider%script(2)%message = text_message('assistant', 'done')
  options%parallel => parallel_hook
  options%max_parallel_tools = 2
  call run()
  call check(.not. error%failed() .and. result%output == 'done', 'parallel result')
  call check(parallel_calls == 2 .and. parallel_max == 2, 'parallel batch metadata')
  call check(provider%last_request%messages(size(provider%last_request%messages))%tool_call_id == 'c2', &
    'parallel order last')

  block
    type(call_limit) :: isolated
    type(sdk_error) :: limit_error
    isolated%model_limit = 1
    call isolated%check('a', 'model', limit_error)
    call isolated%check('b', 'model', limit_error)
    call check(.not. limit_error%failed(), 'call limit isolated run')
    call isolated%check('a', 'model', limit_error)
    call check(string_value(limit_error%code) == 'AGENT_MODEL_CALL_LIMIT', 'call limit run a')
  end block

  call parse_sse_stream('data: {"choices":[{"delta":{"content":"hi"}}]}' // achar(10) // &
    achar(10) // 'data: [DONE]' // achar(10) // achar(10), sse_content, sse_error)
  call check(.not. sse_error%failed() .and. sse_content == 'hi', 'sse complete')
  call parse_sse_stream('data: {"choices":[{"delta":{"content":"hi"}}]}' // achar(10) // &
    achar(10), sse_content, sse_error)
  call check(string_value(sse_error%code) == 'MODEL_STREAM', 'sse truncated')
  call parse_sse_stream('data: {"choices"' // achar(10) // achar(10), sse_content, sse_error)
  call check(string_value(sse_error%code) == 'MODEL_STREAM', 'sse half packet')

  call reset()
  call tool_script()
  options%interrupt_on = [character(len=4) :: 'echo']
  options%on_interrupt => hitl_hook
  hitl_action = 'approve'
  hitl_arguments = ''
  hitl_response = ''
  call run()
  call check(.not. error%failed() .and. result%output == 'done', 'hitl approve')
  call check(invocations == 1, 'hitl approve effect')
  call check(any([(sink%items(i)%kind == 'tool.interrupt', &
    i = 1, size(sink%items))]), 'hitl event')

  call reset()
  call tool_script()
  options%interrupt_on = [character(len=4) :: 'echo']
  options%on_interrupt => hitl_hook
  options%gate => gate
  hitl_action = 'edit'
  hitl_arguments = '{"text":"edited"}'
  call run()
  call check(.not. error%failed() .and. invocations == 1, 'hitl edit effect')
  call check(gate%tool_calls == 2, 'hitl edit reauthorizes')

  call reset()
  call tool_script()
  options%interrupt_on = [character(len=4) :: 'echo']
  options%on_interrupt => hitl_hook
  hitl_action = 'reject'
  call run()
  call check_error('AGENT_APPROVAL_DENIED', 'hitl reject')
  call check(invocations == 0, 'hitl reject effect')

  call reset()
  call tool_script()
  options%interrupt_on = [character(len=4) :: 'echo']
  options%on_interrupt => null()
  call run()
  call check_error('AGENT_INTERRUPT_UNHANDLED', 'hitl unhandled')

  adapter%base_url = 'https://example.test/v1/'
  adapter%model_name = 'test-model'
  adapter%api_key = 'secret'
  adapter%transport => fake_transport
  allocate(adapter_request%messages(3))
  adapter_request%messages(1) = text_message('user', 'hello')
  adapter_request%messages(2) = text_message('assistant', '')
  adapter_request%messages(2)%tool_calls = [tool_call('prior', 'echo', '{"a":1}')]
  adapter_request%messages(3) = text_message('tool', '{"ok":true}', 'prior')
  allocate(adapter_request%tools(1))
  adapter_request%tools(1)%name = 'echo'
  adapter_request%tools(1)%description = 'Echo arguments'
  adapter_text = '{"choices":[{"message":{"content":"hello","tool_calls":['// &
    '{"id":"call-1","type":"function","function":{"name":"echo",'// &
    '"arguments":"{\"text\":\"hi\"}"}}]},"finish_reason":"tool_calls"}],'// &
    '"usage":{"prompt_tokens":3,"completion_tokens":2}}'
  call adapter%generate(adapter_request, adapter_response, error)
  call check(.not. error%failed(), 'openai generate succeeds')
  call check(captured_url == 'https://example.test/v1/chat/completions', &
    'openai endpoint')
  call check(captured_key == 'secret', 'openai api key')
  call check(index(captured_payload, '"model":"test-model"') > 0, 'openai model')
  call check(index(captured_payload, '"role":"assistant","content":"",'// &
    '"tool_calls":[{"id":"prior","type":"function","function":{"name":"echo",'// &
    '"arguments":"{\"a\":1}"}}]') > 0, 'openai tool call history')
  call check(index(captured_payload, '"role":"tool","content":"{\"ok\":true}",'// &
    '"tool_call_id":"prior"') > 0, 'openai tool result history')
  call check(index(captured_payload, '"name":"echo","description":'// &
    '"Echo arguments","parameters":{"type":"object"}') > 0, 'openai tool spec')
  call check(adapter_response%message%content == 'hello', 'openai content')
  call check(allocated(adapter_response%message%tool_calls), &
    'openai tool calls present')
  call check(size(adapter_response%message%tool_calls) == 1, &
    'openai tool call count')
  call check(adapter_response%message%tool_calls(1)%id == 'call-1', &
    'openai tool call id')
  call check(adapter_response%message%tool_calls(1)%name == 'echo', &
    'openai tool call name')
  call check(adapter_response%message%tool_calls(1)%arguments == '{"text":"hi"}', &
    'openai tool call arguments')
  call check(adapter_response%usage%input_tokens == 3 .and. &
    adapter_response%usage%output_tokens == 2, 'openai usage')

  adapter%base_url = ''
  call adapter%generate(adapter_request, adapter_response, error)
  call check(error%code == 'PROVIDER_HTTP', 'openai missing base url')

  adapter%base_url = 'https://example.test/v1'
  adapter_text = '{"choices":[{"message":{"content":"","tool_calls":['// &
    '{"id":"x","function":{"name":"echo","arguments":"broken"}}]}}]}'
  call adapter%generate(adapter_request, adapter_response, error)
  call check(error%code == 'PROVIDER_JSON', 'openai invalid tool arguments')

  if (failures > 0) error stop 1
  print '(a,i0,a)', 'PASS: ', checks, ' native Fortran assertions'
contains
  function fake_transport(url, payload, api_key, transport_error) result(body)
    character(*), intent(in) :: url, payload, api_key
    type(sdk_error), intent(out) :: transport_error
    character(:), allocatable :: body
    captured_url = url
    captured_payload = payload
    captured_key = api_key
    transport_error%code = ''
    body = adapter_text
  end function

  subroutine hitl_hook(ctx, name, arguments, decision_action, new_arguments, &
      response, hook_error)
    class(*), pointer, intent(in) :: ctx
    character(*), intent(in) :: name, arguments
    character(:), allocatable, intent(out) :: decision_action, new_arguments, response
    type(sdk_error), intent(inout) :: hook_error
    if (.false.) then
      if (associated(ctx)) print '(a)', name//arguments
    end if
    decision_action = hitl_action
    response = hitl_response
    if (allocated(hitl_arguments)) then
      new_arguments = hitl_arguments
    end if
    hook_error%code = ''
  end subroutine

  subroutine reset()
    call reset_hooks()
    provider = scripted_model()
    allocate(provider%script(1))
    provider%script(1)%message = text_message('assistant', 'hello')
    sink = recording_sink()
    tools = registry()
    gate = deny_policy()
    invocations = 0
    other_invocations = 0
    echo%spec = tool_spec('echo', 'Echo arguments')
    echo%calls => invocations
    echo%fail = .false.
    call tools%register(echo, error)
    options = agent_options()
    options%provider => provider
    options%tools => tools
    options%events => sink
    state%id = 's1'
    if (allocated(state%messages)) deallocate(state%messages)
    allocate(state%messages(0))
  end subroutine

  subroutine tool_script()
    deallocate(provider%script)
    allocate(provider%script(2))
    provider%script(1)%message = text_message('assistant', '')
    provider%script(1)%message%tool_calls = [tool_call('c1', 'echo', '{"text":"hi"}')]
    provider%script(2)%message = text_message('assistant', 'done')
  end subroutine

  subroutine run()
    call run_agent(options, state, 'hello', 'test-run', result, error)
  end subroutine

  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    failures = failures + 1
    print '(a)', 'FAIL: '//label
  end subroutine

  subroutine check_error(code, label, terminal)
    character(*), intent(in) :: code, label
    logical, optional, intent(in) :: terminal
    logical :: require_terminal
    require_terminal = .true.
    if (present(terminal)) require_terminal = terminal
    call check(string_value(error%code) == code, label)
    if (.not. require_terminal) return
    call check(sink%items(size(sink%items))%kind == 'run.failed', label//' terminal event')
  end subroutine
end program
