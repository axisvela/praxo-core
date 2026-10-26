program core_tests
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_interfaces
  use praxo_agent
  use praxo_runtime
  use praxo_context
  use test_doubles
  implicit none
  type(scripted_model), target :: provider
  type(echo_tool) :: echo
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
  type(event) :: item
  type(context_budget) :: budget
  type(message), allocatable :: messages(:), compacted(:)
  logical :: ok
  character(:), allocatable :: output
  integer, target :: invocations
  integer :: failures = 0, checks = 0, i

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
  call check_error('POLICY_ERROR', 'model policy denial')
  call check(provider%calls == 0, 'model denial occurs before generation')

  call reset()
  call tool_script()
  gate%denied_kind = 'tool.invoke'
  options%gate => gate
  call run()
  call check_error('POLICY_ERROR', 'tool policy denial')
  call check(invocations == 0 .and. size(sink%items) == 2, 'tool denial before invocation and event')

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

  if (failures > 0) error stop 1
  print '(a,i0,a)', 'PASS: ', checks, ' native Fortran assertions'
contains
  subroutine reset()
    provider = scripted_model()
    allocate(provider%script(1))
    provider%script(1)%message = text_message('assistant', 'hello')
    sink = recording_sink()
    tools = registry()
    gate = deny_policy()
    invocations = 0
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
