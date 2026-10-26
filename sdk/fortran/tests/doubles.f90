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
  contains
    procedure :: check => check_denial
  end type
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
    result%allowed = string_value(item%kind) /= string_value(self%denied_kind)
  end function
end module
