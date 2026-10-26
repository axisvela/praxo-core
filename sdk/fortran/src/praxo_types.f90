module praxo_types
  use iso_fortran_env, only: int64
  implicit none
  private
  public :: sdk_error, usage, tool_call, message, tool_spec, request, response
  public :: session, event, action, decision, run_result, text_message, string_value
  public :: string_item, same_string

  type :: string_item
    character(:), allocatable :: value
  end type

  type :: sdk_error
    character(:), allocatable :: code
  contains
    procedure :: failed
  end type

  type :: usage
    integer(int64) :: input_tokens = 0, output_tokens = 0
  end type

  type :: tool_call
    character(:), allocatable :: id, name, arguments
  end type

  type :: message
    character(:), allocatable :: role, content, tool_call_id
    type(tool_call), allocatable :: tool_calls(:)
  end type

  type :: tool_spec
    character(:), allocatable :: name, description
  end type

  type :: request
    type(message), allocatable :: messages(:)
    type(tool_spec), allocatable :: tools(:)
  end type

  type :: response
    type(message) :: message
    type(usage) :: usage
  end type

  type :: session
    character(:), allocatable :: id
    type(message), allocatable :: messages(:)
  end type

  type :: event
    character(:), allocatable :: kind, session_id, run_id, tool_name, arguments
  end type

  type :: action
    character(:), allocatable :: kind, session_id, tool_name, arguments
  end type

  type :: decision
    logical :: allowed = .false.
    character(:), allocatable :: reason
  end type

  type :: run_result
    character(:), allocatable :: run_id, output
    integer :: steps = 0
    type(usage) :: usage
  end type
contains
  logical function same_string(a, b) result(equal)
    character(*), intent(in) :: a, b
    equal = len(a) == len(b) .and. a == b
  end function

  logical function failed(self)
    class(sdk_error), intent(in) :: self
    failed = .false.
    if (allocated(self%code)) failed = len(self%code) > 0
  end function

  function string_value(value) result(text)
    character(:), allocatable, intent(in) :: value
    character(:), allocatable :: text
    text = ''
    if (allocated(value)) text = value
  end function

  function text_message(role, content, call_id) result(item)
    character(*), intent(in) :: role, content
    character(*), optional, intent(in) :: call_id
    type(message) :: item
    item%role = role
    item%content = content
    item%tool_call_id = ''
    if (present(call_id)) item%tool_call_id = call_id
    allocate(item%tool_calls(0))
  end function
end module
