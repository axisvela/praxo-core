module representative_chain_fixtures
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_interfaces
  use praxo_agent
  use praxo_mcp
  use praxo_otel
  use praxo_harmovela
  use praxo_runtime, only: multi_sink
  implicit none
  private
  public :: chain_mcp_transport, chain_otel_transport, chain_harmovela_transport
  public :: chain_clock, mcp_record_tool, delegate_tool, scripted_model
  public :: chain_policy, composed_policy, otel_event_sink, mutate_blocked
  public :: effects, tool_calls, otel_classes, harmovela_classes
  public :: delegation_requested

  integer :: effects(3) = 0
  integer :: tool_calls = 0
  logical :: otel_classes(3) = .false.
  logical :: harmovela_classes(3) = .false.
  logical :: delegation_requested = .false.

  type, extends(model) :: scripted_model
    type(tool_call), allocatable :: steps(:)
    character(:), allocatable :: completion
    integer :: calls = 0
  contains
    procedure :: generate => generate_scripted
  end type

  type, extends(tool) :: mcp_record_tool
    type(mcp_client), pointer :: client => null()
  contains
    procedure :: invoke => invoke_mcp_record
  end type

  type, extends(policy) :: chain_policy
    logical :: child_scope = .false.
  contains
    procedure :: check => check_chain
  end type

  type, extends(policy) :: composed_policy
    class(policy), pointer :: outer => null()
    class(policy), pointer :: inner => null()
  contains
    procedure :: check => check_composed
  end type

  type, extends(tool) :: delegate_tool
  contains
    procedure :: invoke => invoke_delegate
  end type

  type, extends(event_sink) :: otel_event_sink
    type(otel_sink) :: inner
  contains
    procedure :: emit => emit_otel_event
  end type
contains
  subroutine chain_mcp_transport(method, params, result, error)
    character(*), intent(in) :: method, params
    character(:), allocatable, intent(out) :: result
    type(sdk_error), intent(out) :: error
    error%code = ''
    if (same_string(method, 'initialize')) then
      result = '{"protocolVersion":"2024-11-05","serverInfo":{"name":"chain"}}'
    else if (same_string(method, 'tools/list')) then
      result = '{"tools":[{"name":"record","description":"Record a target"}]}'
    else if (same_string(method, 'tools/call')) then
      tool_calls = tool_calls + 1
      if (index(params, '"target":"parent"') > 0) effects(1) = effects(1) + 1
      if (index(params, '"target":"child"') > 0) effects(2) = effects(2) + 1
      if (index(params, '"target":"blocked"') > 0) effects(3) = effects(3) + 1
      result = '{"content":[{"type":"text","text":"recorded"}]}'
    else
      result = '{}'
    end if
  end subroutine

  subroutine chain_otel_transport(method, url, content_type, body, response, error)
    character(*), intent(in) :: method, url, content_type, body
    type(otel_response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    error%code = ''
    response%body = ''
    if (len(method) == 0 .or. len(url) == 0 .or. len(content_type) == 0) then
      response%status = 500
      return
    end if
    if (index(body, 'praxo.run.started') > 0) otel_classes(1) = .true.
    if (index(body, 'praxo.tool.call') > 0) otel_classes(2) = .true.
    if (index(body, 'praxo.run.completed') > 0) otel_classes(3) = .true.
    response%status = 200
  end subroutine

  subroutine chain_harmovela_transport(method, url, content_type, body, response, error)
    character(*), intent(in) :: method, url, content_type, body
    type(harmovela_response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    error%code = ''
    response%body = ''
    if (len(method) == 0 .or. len(url) == 0 .or. len(content_type) == 0) then
      response%status = 500
      return
    end if
    if (index(body, '"type":"run.started"') > 0) harmovela_classes(1) = .true.
    if (index(body, '"type":"tool.call"') > 0) harmovela_classes(2) = .true.
    if (index(body, '"type":"run.completed"') > 0) harmovela_classes(3) = .true.
    response%status = 204
  end subroutine

  function chain_clock() result(epoch)
    integer(int64) :: epoch
    epoch = 1794294000000000000_int64
  end function

  subroutine generate_scripted(self, req, res, error)
    class(scripted_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    if (.false.) then
      if (size(req%messages) < 0) res%message%content = 'x'
    end if
    self%calls = self%calls + 1
    error%code = ''
    if (allocated(self%steps)) then
      if (self%calls <= size(self%steps)) then
        res%message = text_message('assistant', '')
        res%message%tool_calls = [self%steps(self%calls)]
      else
        res%message = text_message('assistant', string_value(self%completion))
      end if
    else
      res%message = text_message('assistant', string_value(self%completion))
    end if
    res%usage%input_tokens = 1
    res%usage%output_tokens = 1
  end subroutine

  subroutine invoke_mcp_record(self, arguments, output, error)
    class(mcp_record_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    output = ''
    error%code = ''
    if (.not. associated(self%client)) then
      error%code = 'MCP_TRANSPORT'
      return
    end if
    output = self%client%call_tool(string_value(self%spec%name), arguments, error)
  end subroutine

  function check_chain(self, item) result(verdict)
    class(chain_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: verdict
    character(:), allocatable :: kind, name
    verdict%allowed = .false.
    verdict%reason = 'denied by chain policy'
    kind = string_value(item%kind)
    if (same_string(kind, 'model.generate')) then
      verdict%allowed = .true.
      verdict%reason = ''
      return
    end if
    if (.not. same_string(kind, 'tool.invoke')) return
    name = string_value(item%tool_name)
    if (self%child_scope) then
      if (.not. same_string(name, 'record')) return
    else
      if (.not. same_string(name, 'record') .and. &
          .not. same_string(name, 'delegate')) return
    end if
    if (same_string(name, 'record')) then
      if (index(string_value(item%arguments), 'blocked') > 0) return
    end if
    verdict%allowed = .true.
    verdict%reason = ''
  end function

  function check_composed(self, item) result(verdict)
    class(composed_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: verdict
    verdict%allowed = .false.
    verdict%reason = 'composed policy denied'
    if (.not. associated(self%outer)) return
    verdict = self%outer%check(item)
    if (.not. verdict%allowed) return
    if (.not. associated(self%inner)) return
    verdict = self%inner%check(item)
  end function

  subroutine invoke_delegate(self, arguments, output, error)
    class(delegate_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (.false.) then
      if (len(arguments) < 0) output = ''
    end if
    delegation_requested = .true.
    output = 'delegated'
    error%code = ''
  end subroutine

  subroutine emit_otel_event(self, item)
    class(otel_event_sink), intent(inout) :: self
    type(event), intent(in) :: item
    call self%inner%emit(item)
  end subroutine

  subroutine mutate_blocked(ctx, name, arguments, error)
    class(*), pointer, intent(in) :: ctx
    character(:), allocatable, intent(inout) :: name, arguments
    type(sdk_error), intent(inout) :: error
    if (.false.) then
      if (associated(ctx)) name = name
    end if
    arguments = '{"target":"blocked"}'
    error%code = ''
  end subroutine
end module

program representative_chain_tests
  use praxo_types
  use praxo_interfaces, only: registry
  use praxo_agent
  use praxo_mcp
  use praxo_otel
  use praxo_harmovela
  use praxo_runtime, only: multi_sink
  use representative_chain_fixtures
  implicit none
  type(mcp_client), target :: client
  type(mcp_record_tool) :: record_tool
  type(delegate_tool) :: delegate
  type(registry), target :: parent_tools, child_tools
  type(scripted_model), target :: parent_model, child_model, denial_model
  type(chain_policy), target :: parent_gate, child_gate
  type(composed_policy), target :: composed_gate
  type(otel_sink) :: otel
  type(otel_event_sink), target :: otel_events
  type(harmovela_sink), target :: harmovela
  type(multi_sink), target :: events
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error, denial_error
  character(:), allocatable :: catalog
  integer :: checks = 0, failures = 0

  client = mcp_client_new(chain_mcp_transport)
  call client%initialize(error)
  call check(.not. error%failed(), 'mcp initialize')
  catalog = client%list_tools(error)
  call check(.not. error%failed(), 'mcp tools/list')
  call check(index(catalog, '"name":"record"') > 0, 'mcp advertises record')

  record_tool%spec = tool_spec('record', 'Record a target')
  record_tool%client => client
  call parent_tools%register(record_tool, error)
  call check(.not. error%failed(), 'parent registry')
  call child_tools%register(record_tool, error)
  call check(.not. error%failed(), 'child registry')

  child_gate%child_scope = .true.
  composed_gate%outer => parent_gate
  composed_gate%inner => child_gate

  delegate%spec = tool_spec('delegate', 'Request a governed child')
  call parent_tools%register(delegate, error)
  call check(.not. error%failed(), 'delegate registered')

  otel = otel_sink_new('http://otel.test/v1/traces', 'praxo-chain', chain_otel_transport)
  otel_events%inner = otel
  harmovela%base_url = 'http://harmovela.test/aep/api/'
  harmovela%source = 'praxo-chain'
  harmovela%spec_version = '0.2'
  harmovela%transport => chain_harmovela_transport
  harmovela%clock => chain_clock
  call events%add(otel_events)
  call events%add(harmovela)

  allocate(parent_model%steps(2))
  parent_model%steps(1) = tool_call('p1', 'record', '{"target":"parent"}')
  parent_model%steps(2) = tool_call('p2', 'delegate', '{"task":"child"}')
  parent_model%completion = 'DONE'
  allocate(child_model%steps(1))
  child_model%steps(1) = tool_call('c1', 'record', '{"target":"child"}')
  child_model%completion = 'CHILD-DONE'

  options = agent_options()
  options%provider => parent_model
  options%tools => parent_tools
  options%gate => parent_gate
  options%events => events
  options%require_policy = .true.
  options%require_tool_scope = .true.
  options%max_steps = 6
  allocate(character(len=16) :: options%allowed_tools(2))
  options%allowed_tools(1) = 'record'
  options%allowed_tools(2) = 'delegate'
  state%id = 'chain-parent'
  allocate(state%messages(0))
  call run_agent(options, state, 'run representative chain', 'chain-parent-run', &
    result, error)
  call check(.not. error%failed(), 'parent run succeeds')
  call check(string_value(result%output) == 'DONE', 'parent output DONE')
  call check(effects(1) == 1, 'parent effect is one')
  call check(delegation_requested, 'delegate tool requested child')

  options = agent_options()
  options%provider => child_model
  options%tools => child_tools
  options%gate => composed_gate
  options%events => events
  options%require_policy = .true.
  options%require_tool_scope = .true.
  options%max_steps = 3
  allocate(character(len=16) :: options%allowed_tools(1))
  options%allowed_tools(1) = 'record'
  state%id = 'chain-child'
  if (allocated(state%messages)) deallocate(state%messages)
  allocate(state%messages(0))
  call run_agent(options, state, 'record once', 'chain-child-run', result, error)
  call check(.not. error%failed(), 'child run succeeds')
  call check(string_value(result%output) == 'CHILD-DONE', 'child output')
  call check(effects(2) == 1, 'child effect is one')
  call check(child_model%calls >= 2, 'child model calls at least two')
  call check(all(otel_classes), 'otel receives three event classes')
  call check(all(harmovela_classes), 'harmovela receives three event classes')

  effects = 0
  tool_calls = 0
  otel_classes = .false.
  harmovela_classes = .false.
  allocate(denial_model%steps(1))
  denial_model%steps(1) = tool_call('d1', 'record', '{"target":"safe"}')
  denial_model%completion = 'UNEXPECTED'
  options = agent_options()
  options%provider => denial_model
  options%tools => parent_tools
  options%gate => parent_gate
  options%events => events
  options%require_policy = .true.
  options%require_tool_scope = .true.
  options%max_steps = 2
  allocate(character(len=16) :: options%allowed_tools(1))
  options%allowed_tools(1) = 'record'
  allocate(options%middleware(1))
  options%middleware(1)%before_tool => mutate_blocked
  state%id = 'chain-denial'
  if (allocated(state%messages)) deallocate(state%messages)
  allocate(state%messages(0))
  call run_agent(options, state, 'record once', 'chain-denial-run', result, denial_error)
  call check(string_value(denial_error%code) == 'AGENT_POLICY_DENIED', &
    'edited argument denied')
  call check(effects(3) == 0, 'blocked effect is zero')
  call check(tool_calls == 0, 'blocked tool never executed')
  call check(denial_model%calls == 1, 'denial model called once')

  if (failures == 0) then
    print '(a,i0,a)', 'Fortran representative chain: ', checks, ' checks passed'
  else
    print '(a,i0,a)', 'Fortran representative chain: ', failures, ' failures'
    error stop 1
  end if
contains
  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    failures = failures + 1
    print '(a)', 'FAIL: '//label
  end subroutine
end program
