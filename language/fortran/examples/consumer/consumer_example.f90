module consumer_example_types
  use praxo_types
  use praxo_interfaces
  implicit none

  integer :: consumer_effects = 0
  character(:), allocatable :: consumer_target

  type, extends(model) :: fixture_model
    integer :: calls = 0
  contains
    procedure :: generate => generate_fixture
  end type

  type, extends(tool) :: record_tool
  contains
    procedure :: invoke => invoke_record
  end type

  type, extends(policy) :: target_policy
    integer :: calls = 0
  contains
    procedure :: check => check_target
  end type
contains
  subroutine generate_fixture(self, req, res, error)
    class(fixture_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    if (.false.) res%message%content = req%messages(1)%content
    self%calls = self%calls + 1
    if (self%calls == 1) then
      res%message = text_message('assistant', '')
      res%message%tool_calls = [tool_call('record-1', 'record', &
        '{"target":"'//consumer_target//'"}')]
    else
      res%message = text_message('assistant', 'recorded')
    end if
    error%code = ''
  end subroutine

  subroutine invoke_record(self, arguments, output, error)
    class(record_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (.false.) print '(a)', self%spec%name
    consumer_effects = consumer_effects + 1
    output = arguments
    error%code = ''
  end subroutine

  function check_target(self, item) result(result)
    class(target_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: result
    self%calls = self%calls + 1
    result%allowed = .true.
    result%reason = ''
    if (item%kind /= 'tool.invoke') return
    if (item%tool_name /= 'record') then
      result%allowed = .false.
      result%reason = 'only record is permitted'
      return
    end if
    if (index(item%arguments, '"target":"public"') == 0) then
      result%allowed = .false.
      result%reason = 'only the public target is permitted'
    end if
  end function
end module

program consumer_example
  use praxo_types
  use praxo_interfaces
  use praxo_agent, only: agent_options, run_agent
  use consumer_example_types
  implicit none

  type(fixture_model), target :: provider
  type(record_tool) :: recorder
  type(registry), target :: tools
  type(target_policy), target :: gate
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error

  recorder%spec = tool_spec('record', 'Record a target in an in-memory counter.')
  call tools%register(recorder, error)
  if (error%failed()) stop 1
  state%id = 'consumer'
  allocate(state%messages(0))

  options%provider => provider
  options%tools => tools
  options%gate => gate
  options%allowed_tools = [character(6) :: 'record']
  options%max_steps = 3

  consumer_target = 'public'
  consumer_effects = 0
  call run_agent(options, state, 'Record the requested target.', &
    'consumer-public', result, error)
  if (error%failed() .or. string_value(result%output) /= 'recorded' .or. &
      consumer_effects /= 1) then
    print '(a)', 'allow verification failed'
    stop 1
  end if
  print '(a,i0)', 'allow: recorded; effects=', consumer_effects

  provider%calls = 0
  consumer_target = 'private'
  consumer_effects = 0
  call run_agent(options, state, 'Record the requested target.', &
    'consumer-private', result, error)
  if (.not. error%failed() .or. &
      string_value(error%code) /= 'AGENT_POLICY_DENIED' .or. &
      consumer_effects /= 0) then
    print '(a)', 'deny verification failed'
    stop 1
  end if
  print '(a,i0)', 'deny: policy rejected; effects=', consumer_effects
end program
