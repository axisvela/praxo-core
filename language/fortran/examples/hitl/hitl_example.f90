module hitl_example_types
  use praxo_types
  use praxo_interfaces
  implicit none

  integer :: effects = 0
  character(:), allocatable :: hitl_action, hitl_arguments

  type, extends(model) :: write_model
    integer :: calls = 0
  contains
    procedure :: generate => generate_write
  end type

  type, extends(tool) :: write_tool
  contains
    procedure :: invoke => invoke_write
  end type

  type, extends(policy) :: visibility_policy
    integer :: calls = 0
  contains
    procedure :: check => check_visibility
  end type
contains
  subroutine generate_write(self, req, res, error)
    class(write_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    if (.false.) res%message%content = req%messages(1)%content
    self%calls = self%calls + 1
    if (self%calls == 1) then
      res%message = text_message('assistant', '')
      res%message%tool_calls = [tool_call('call-1', 'write_note', &
        '{"text":"hello","visibility":"public"}')]
    else
      res%message = text_message('assistant', 'done')
    end if
    error%code = ''
  end subroutine

  subroutine invoke_write(self, arguments, output, error)
    class(write_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (.false.) print '(a)', self%spec%name
    effects = effects + 1
    output = arguments
    error%code = ''
  end subroutine

  function check_visibility(self, item) result(result)
    class(visibility_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: result
    self%calls = self%calls + 1
    result%allowed = .true.
    result%reason = ''
    if (item%kind /= 'tool.invoke') return
    if (item%tool_name /= 'write_note') then
      result%allowed = .false.
      return
    end if
    if (index(item%arguments, '"visibility":"private"') > 0) then
      result%allowed = .false.
      result%reason = 'private notes are not approved'
    end if
  end function

  subroutine hitl_hook(ctx, name, arguments, decision_action, new_arguments, &
      response, error)
    class(*), pointer, intent(in) :: ctx
    character(*), intent(in) :: name, arguments
    character(:), allocatable, intent(out) :: decision_action, new_arguments, response
    type(sdk_error), intent(inout) :: error
    if (.false.) then
      if (associated(ctx)) print '(a)', name//arguments
    end if
    decision_action = hitl_action
    response = ''
    if (hitl_action == 'edit') new_arguments = hitl_arguments
    error%code = ''
  end subroutine
end module

program hitl_example
  use praxo_types
  use praxo_interfaces
  use praxo_agent, only: agent_options, run_agent
  use hitl_example_types
  implicit none

  type(write_model), target :: provider
  type(write_tool) :: writer
  type(registry), target :: tools
  type(visibility_policy), target :: gate
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error

  writer%spec = tool_spec('write_note', 'Write a note')
  call tools%register(writer, error)
  if (error%failed()) stop 1
  state%id = 'session-1'
  allocate(state%messages(0))

  options%provider => provider
  options%tools => tools
  options%gate => gate
  options%interrupt_on = [character(10) :: 'write_note']
  options%on_interrupt => hitl_hook

  hitl_action = 'approve'
  hitl_arguments = ''
  effects = 0
  call run_agent(options, state, 'write', 'run-approve', result, error)
  if (error%failed() .or. effects /= 1) stop 1
  print '(a,i0)', 'approve: written; effects=', effects

  provider%calls = 0
  hitl_action = 'edit'
  hitl_arguments = '{"text":"hello","visibility":"private"}'
  effects = 0
  call run_agent(options, state, 'write', 'run-edit', result, error)
  if (string_value(error%code) /= 'AGENT_POLICY_DENIED') stop 1
  if (effects /= 0) stop 1
  print '(a,i0)', 'edit: policy rejected; effects=', effects
end program
