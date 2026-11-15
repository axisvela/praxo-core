module live_model_types
  use praxo_types
  use praxo_interfaces
  implicit none

  public :: time_tool, get_time_policy, missing_transport

  type, extends(tool) :: time_tool
  contains
    procedure :: invoke => invoke_time
  end type

  type, extends(policy) :: get_time_policy
    integer :: calls = 0
  contains
    procedure :: check => check_get_time
  end type
contains
  subroutine invoke_time(self, arguments, output, error)
    class(time_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    integer :: values(8)
    character(32) :: text
    character(1) :: suffix
    if (.false.) print '(a)', self%spec%name
    suffix = 'Z'
    if (index(arguments, '"zone":"local"') > 0) suffix = ' '
    call date_and_time(values=values)
    write(text, '(I4.4,"-",I2.2,"-",I2.2,"T",I2.2,":",I2.2,":",I2.2,A)') &
      values(1), values(2), values(3), values(5), values(6), values(7), suffix
    output = trim(text)
    error%code = ''
  end subroutine

  function check_get_time(self, item) result(result)
    class(get_time_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: result
    self%calls = self%calls + 1
    result%allowed = .true.
    result%reason = ''
    if (item%kind == 'model.generate') return
    if (item%kind == 'tool.invoke' .and. item%tool_name == 'get_time') return
    result%allowed = .false.
    result%reason = 'only get_time is permitted'
  end function

  function missing_transport(url, payload, api_key, error) result(body)
    character(*), intent(in) :: url, payload, api_key
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (.false.) print '(a)', url//payload//api_key
    body = ''
    error%code = 'PROVIDER_HTTP'
  end function
end module

program live_model_example
  use praxo_types
  use praxo_interfaces
  use praxo_agent, only: agent_options, run_agent
  use praxo_openai, only: openai_compatible
  use live_model_types
  implicit none

  type(openai_compatible), target :: provider
  type(time_tool) :: clock
  type(registry), target :: tools
  type(get_time_policy), target :: gate
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error
  character(:), allocatable :: base_url, model_name, api_key, prompt

  base_url = env_or('PRAXO_BASE_URL', 'http://localhost:11434/v1')
  model_name = env_or('PRAXO_MODEL', 'qwen3.5:4b')
  api_key = env_or('PRAXO_API_KEY', '')
  prompt = env_or('PRAXO_PROMPT', &
    'What time is it? Use get_time with zone set to utc and reply with the time.')

  clock%spec = tool_spec('get_time', &
    'Return the current time in ISO 8601 format for the requested zone.')
  call tools%register(clock, error)
  if (error%failed()) stop 1
  state%id = 'live-model'
  allocate(state%messages(0))

  provider%base_url = base_url
  provider%model_name = model_name
  provider%api_key = api_key
  provider%transport => missing_transport

  options%provider => provider
  options%tools => tools
  options%gate => gate
  options%system_prompt = &
    'You are a concise assistant. Use the provided tools when they help.'
  options%max_steps = 4
  options%allowed_tools = [character(8) :: 'get_time']

  call run_agent(options, state, prompt, 'live-model', result, error)
  if (error%failed()) then
    print '(a)', 'live model run failed: '//string_value(error%code)
    print '(a)', 'Check PRAXO_BASE_URL ('//base_url//')'
    print '(a)', 'Check PRAXO_MODEL ('//model_name//')'
    print '(a)', 'Check PRAXO_API_KEY and the caller-owned transport'
    stop 1
  end if
  print '(a)', string_value(result%output)
contains
  function env_or(name, fallback) result(value)
    character(*), intent(in) :: name, fallback
    character(:), allocatable :: value
    character(len=1024) :: buffer
    integer :: length, status
    call get_environment_variable(name, buffer, length, status, .false.)
    if (status /= 0 .or. length == 0) then
      value = fallback
    else
      value = buffer(1:length)
    end if
  end function
end program
