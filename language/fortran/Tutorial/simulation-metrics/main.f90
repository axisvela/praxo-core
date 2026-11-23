module simulation_tutorial_types
  use praxo_types
  use praxo_interfaces
  implicit none

  character(:), allocatable :: simulation_run
  logical :: simulation_fail = .false.
  integer :: simulation_reads = 0

  type, extends(model) :: fixture_model
    integer :: calls = 0
  contains
    procedure :: generate => generate_fixture
  end type

  type, extends(tool) :: read_simulation_tool
  contains
    procedure :: invoke => invoke_read
  end type

  type, extends(tool) :: draft_summary_tool
  contains
    procedure :: invoke => invoke_draft
  end type

  type, extends(policy) :: scope_policy
    integer :: checks = 0
  contains
    procedure :: check => check_scope
  end type
contains
  subroutine generate_fixture(self, req, res, error)
    class(fixture_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    integer :: i, tool_count
    character(:), allocatable :: first, second
    tool_count = 0
    first = ''
    second = ''
    do i = 1, size(req%messages)
      if (req%messages(i)%role /= 'tool') cycle
      tool_count = tool_count + 1
      if (tool_count == 1) first = string_value(req%messages(i)%content)
      if (tool_count == 2) second = string_value(req%messages(i)%content)
    end do
    self%calls = self%calls + 1
    error%code = ''
    if (tool_count == 0) then
      res%message = text_message('assistant', '')
      res%message%tool_calls = [tool_call('read-1', 'read_simulation', &
        '{"run_id":"'//simulation_run//'"}')]
      return
    end if
    if (tool_count == 1) then
      res%message = text_message('assistant', '')
      res%message%tool_calls = [tool_call('summary-1', 'draft_summary', &
        '{"run_id":"'//simulation_run//'","action":"publish_report"}')]
      return
    end if
    res%message = text_message('assistant', &
      '{"simulation":'//first//',"summary":'//second// &
      ',"policy":"computed metrics only; publication remains application-owned"'// &
      ',"simulation_writes":0}')
  end subroutine

  subroutine invoke_read(self, arguments, output, error)
    class(read_simulation_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (.false.) print '(a)', self%spec%name
    if (.false.) print '(a)', arguments
    simulation_reads = simulation_reads + 1
    error%code = ''
    if (simulation_fail) then
      error%code = 'SIMULATION_SOURCE_UNAVAILABLE'
      output = ''
      return
    end if
    output = '{"run_id":"sim-100","samples":10,"mean":122.5,'// &
      '"minimum":100.0,"maximum":145.0,"peak_to_peak":45.0,'// &
      '"threshold":135.0,"exceedances":2,"source":"metric_fixture"}'
  end subroutine

  subroutine invoke_draft(self, arguments, output, error)
    class(draft_summary_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (.false.) print '(a)', self%spec%name
    if (.false.) print '(a)', arguments
    error%code = ''
    output = '{"run_id":"sim-100","action":"publish_report",'// &
      '"status":"draft_only","review_required":true,"simulation_writes":0}'
  end subroutine

  function check_scope(self, item) result(result)
    class(scope_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: result
    self%checks = self%checks + 1
    result%allowed = .true.
    result%reason = ''
    if (item%kind /= 'tool.invoke') return
    if (index(item%arguments, '"run_id":"sim-100"') == 0) then
      result%allowed = .false.
      result%reason = 'only sim-100 is permitted'
      return
    end if
    if (item%tool_name == 'read_simulation') return
    if (item%tool_name == 'draft_summary') then
      result%allowed = index(item%arguments, '"action":"publish_report"') > 0
      if (.not. result%allowed) result%reason = 'only publish_report is allowed'
      return
    end if
    result%allowed = .false.
    result%reason = 'unknown tool'
  end function
end module

program simulation_metrics
  use praxo_types
  use praxo_interfaces
  use praxo_agent, only: agent_options, run_agent
  use simulation_tutorial_types
  implicit none

  type(fixture_model), target :: provider
  type(read_simulation_tool) :: reader
  type(draft_summary_tool) :: drafter
  type(registry), target :: tools
  type(scope_policy), target :: gate
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error

  reader%spec = tool_spec('read_simulation', 'Compute fixed simulation metrics.')
  drafter%spec = tool_spec('draft_summary', 'Draft a report summary without publishing.')
  call tools%register(reader, error)
  if (error%failed()) stop 1
  call tools%register(drafter, error)
  if (error%failed()) stop 1
  state%id = 'fortran-simulation'
  allocate(state%messages(0))

  options%provider => provider
  options%tools => tools
  options%gate => gate
  options%allowed_tools = [character(15) :: 'read_simulation', 'draft_summary']
  options%max_steps = 5

  simulation_run = 'sim-100'
  simulation_fail = .false.
  simulation_reads = 0
  provider%calls = 0
  call run_agent(options, state, &
    'Review the fixed simulation metrics and draft a report summary.', &
    'simulation-run', result, error)
  if (error%failed()) stop 1
  if (index(string_value(result%output), '"mean":122.5') == 0 .or. &
      index(string_value(result%output), '"exceedances":2') == 0 .or. &
      index(string_value(result%output), '"status":"draft_only"') == 0 .or. &
      index(string_value(result%output), '"simulation_writes":0') == 0 .or. &
      simulation_reads /= 1) then
    print '(a)', 'success verification failed'
    stop 1
  end if
  print '(a)', 'success: sim-100 mean=122.5 exceedances=2 status=draft_only writes=0 reads=1'

  simulation_run = 'sim-200'
  simulation_reads = 0
  provider%calls = 0
  call run_agent(options, state, &
    'Review the fixed simulation metrics and draft a report summary.', &
    'simulation-deny', result, error)
  if (.not. error%failed() .or. &
      string_value(error%code) /= 'AGENT_POLICY_DENIED' .or. &
      simulation_reads /= 0) then
    print '(a)', 'deny verification failed'
    stop 1
  end if
  print '(a)', 'deny: AGENT_POLICY_DENIED reads=0'

  simulation_run = 'sim-100'
  simulation_fail = .true.
  simulation_reads = 0
  provider%calls = 0
  call run_agent(options, state, &
    'Review the fixed simulation metrics and draft a report summary.', &
    'simulation-fail', result, error)
  if (.not. error%failed() .or. &
      string_value(error%code) /= 'SIMULATION_SOURCE_UNAVAILABLE' .or. &
      simulation_reads /= 1) then
    print '(a)', 'failure verification failed'
    stop 1
  end if
  print '(a)', 'failure: SIMULATION_SOURCE_UNAVAILABLE reads=1'
end program
