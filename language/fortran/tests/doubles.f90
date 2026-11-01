module test_doubles
  use praxo_types
  use praxo_interfaces
  use praxo_schema, only: validation_error
  implicit none
  character(:), allocatable :: repair_content
  character(:), allocatable :: repair_previous
  integer :: repair_error_count = 0, repair_attempt = 0

  type, extends(model) :: scripted_model
    type(response), allocatable :: script(:)
    type(request) :: last_request
    integer :: calls = 0, fail_at = 0
  contains
    procedure :: generate => generate_script
  end type

  type, extends(tool) :: echo_tool
    integer, pointer :: calls => null()
    logical :: fail = .false.
  contains
    procedure :: invoke => invoke_echo
  end type

  type, extends(policy) :: deny_policy
    character(:), allocatable :: denied_kind
    integer :: calls = 0
    integer :: tool_calls = 0
  contains
    procedure :: check => check_denial
  end type
  integer :: hook_before_tool_calls = 0
  integer :: hook_after_run_calls = 0
  integer :: hook_before_run_calls = 0
  logical :: hook_mutate_arguments = .false.
  logical :: hook_rename_tool = .false.
  logical :: hook_fail_before_run = .false.
  logical :: hook_fail_after_run = .false.
  character(:), allocatable :: hook_renamed_tool
  character(:), allocatable :: hook_last_name
  character(:), allocatable :: hook_last_arguments
contains
  subroutine repair_fixture(previous, errors, attempt, repaired, error)
    character(*), intent(in) :: previous
    type(validation_error), intent(in) :: errors(:)
    integer, intent(in) :: attempt
    character(:), allocatable, intent(out) :: repaired
    type(sdk_error), intent(out) :: error
    repair_previous = previous
    repair_error_count = size(errors)
    repair_attempt = attempt
    if (attempt < 1 .or. .not. allocated(repair_content)) then
      error%code = 'TEST_REPAIR_FAILURE'
      return
    end if
    repaired = string_value(repair_content)
  end subroutine

  subroutine generate_script(self, req, res, error)
    class(scripted_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    self%calls = self%calls + 1
    self%last_request = req
    if (self%calls == self%fail_at) then
      error%code = 'TEST_MODEL_FAILURE'
    else if (.not. allocated(self%script)) then
      error%code = 'TEST_SCRIPT_EXHAUSTED'
    else if (self%calls > size(self%script)) then
      error%code = 'TEST_SCRIPT_EXHAUSTED'
    else
      res = self%script(self%calls)
    end if
  end subroutine

  subroutine invoke_echo(self, arguments, output, error)
    class(echo_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    if (associated(self%calls)) self%calls = self%calls + 1
    if (self%fail) then
      error%code = 'TEST_TOOL_FAILURE'
    else
      output = arguments
    end if
  end subroutine

  function check_denial(self, item) result(result)
    class(deny_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: result
    self%calls = self%calls + 1
    if (string_value(item%kind) == 'tool.invoke') self%tool_calls = self%tool_calls + 1
    result%allowed = string_value(item%kind) /= string_value(self%denied_kind)
  end function
  subroutine reset_hooks()
    hook_before_tool_calls = 0
    hook_after_run_calls = 0
    hook_before_run_calls = 0
    hook_mutate_arguments = .false.
    hook_rename_tool = .false.
    hook_fail_before_run = .false.
    hook_fail_after_run = .false.
    hook_renamed_tool = ''
    hook_last_name = ''
    hook_last_arguments = ''
  end subroutine

  subroutine hook_before_run_record(ctx, run_id, prompt, error)
    class(*), pointer, intent(in) :: ctx
    character(*), intent(in) :: run_id, prompt
    type(sdk_error), intent(inout) :: error
    hook_before_run_calls = hook_before_run_calls + 1
    if (len(run_id) < 0) error%code = prompt
  end subroutine

  subroutine hook_before_run_fail(ctx, run_id, prompt, error)
    class(*), pointer, intent(in) :: ctx
    character(*), intent(in) :: run_id, prompt
    type(sdk_error), intent(inout) :: error
    hook_before_run_calls = hook_before_run_calls + 1
    if (len(prompt) < 0) error%code = run_id
    if (hook_fail_before_run) error%code = 'STARTUP_FAILED'
  end subroutine

  subroutine hook_after_run_record(ctx, result, error, hook_error)
    class(*), pointer, intent(in) :: ctx
    type(run_result), intent(in) :: result
    type(sdk_error), intent(in) :: error
    type(sdk_error), intent(inout) :: hook_error
    hook_after_run_calls = hook_after_run_calls + 1
    if (result%steps < 0) hook_error%code = string_value(error%code)
  end subroutine

  subroutine hook_after_run_fail(ctx, result, error, hook_error)
    class(*), pointer, intent(in) :: ctx
    type(run_result), intent(in) :: result
    type(sdk_error), intent(in) :: error
    type(sdk_error), intent(inout) :: hook_error
    hook_after_run_calls = hook_after_run_calls + 1
    if (result%steps < 0) hook_error%code = string_value(error%code)
    if (hook_fail_after_run) hook_error%code = 'CLEANUP_FAILED'
  end subroutine

  subroutine hook_before_tool(ctx, name, arguments, error)
    class(*), pointer, intent(in) :: ctx
    character(:), allocatable, intent(inout) :: name, arguments
    type(sdk_error), intent(inout) :: error
    hook_before_tool_calls = hook_before_tool_calls + 1
    hook_last_name = name
    hook_last_arguments = arguments
    if (len(name) < 0) error%code = arguments
    if (hook_rename_tool) name = hook_renamed_tool
    if (hook_mutate_arguments) arguments = '{"text":"mutated"}'
  end subroutine

end module
