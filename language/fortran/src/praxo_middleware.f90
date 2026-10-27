module praxo_middleware
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_interfaces
  use praxo_json
  use praxo_schema
  implicit none
  private
  public :: call_limit, tool_selection, fallback_model, structured_model, structured_output
  public :: redact_email, redact_json_email, repair_interface

  type :: run_count
    character(:), allocatable :: id
    integer(int64) :: model = 0, tool = 0
  end type

  type :: call_limit
    integer(int64) :: model_limit = 0, tool_limit = 0
    type(run_count), allocatable, private :: runs(:)
  contains
    procedure :: check => check_limit
    procedure :: clear => clear_limits
  end type

  type :: tool_selection
    type(string_item), allocatable :: selected(:)
  contains
    procedure :: check => check_selected
    procedure :: advertised
  end type

  type, extends(model) :: fallback_model
    class(model), pointer :: primary => null(), fallback => null()
  contains
    procedure :: generate => generate_fallback
  end type

  type, extends(model) :: structured_model
    class(model), pointer :: provider => null()
    character(:), allocatable :: schema
    integer :: max_repairs = 0
    procedure(repair_interface), pointer, nopass :: repair => null()
  contains
    procedure :: generate => generate_structured
  end type

  abstract interface
    subroutine repair_interface(previous, errors, attempt, repaired, error)
      import validation_error, sdk_error
      character(*), intent(in) :: previous
      type(validation_error), intent(in) :: errors(:)
      integer, intent(in) :: attempt
      character(:), allocatable, intent(out) :: repaired
      type(sdk_error), intent(out) :: error
    end subroutine
  end interface
contains
  subroutine check_limit(self, run_id, kind, error)
    class(call_limit), intent(inout) :: self
    character(*), intent(in) :: run_id, kind
    type(sdk_error), intent(out) :: error
    type(run_count), allocatable :: expanded(:)
    integer :: i, count
    if (kind /= 'model' .and. kind /= 'tool') then
      error%code = 'INVALID_REQUEST'
      return
    end if
    count = 0
    if (allocated(self%runs)) count = size(self%runs)
    do i = 1, count
      if (len(self%runs(i)%id) /= len(run_id)) cycle
      if (self%runs(i)%id == run_id) exit
    end do
    if (i > count) then
      allocate(expanded(count + 1))
      if (count > 0) expanded(:count) = self%runs
      expanded(count + 1)%id = run_id
      call move_alloc(expanded, self%runs)
      i = count + 1
    end if
    if (kind == 'model') then
      if (self%model_limit > 0) then
        if (self%runs(i)%model >= self%model_limit) then
          error%code = 'AGENT_MODEL_CALL_LIMIT'
          return
        end if
      end if
      if (self%runs(i)%model < huge(0_int64)) self%runs(i)%model = self%runs(i)%model + 1
    else
      if (self%tool_limit > 0) then
        if (self%runs(i)%tool >= self%tool_limit) then
          error%code = 'AGENT_TOOL_CALL_LIMIT'
          return
        end if
      end if
      if (self%runs(i)%tool < huge(0_int64)) self%runs(i)%tool = self%runs(i)%tool + 1
    end if
  end subroutine

  subroutine clear_limits(self)
    class(call_limit), intent(inout) :: self
    if (allocated(self%runs)) deallocate(self%runs)
  end subroutine

  subroutine check_selected(self, name, error)
    class(tool_selection), intent(in) :: self
    character(*), intent(in) :: name
    type(sdk_error), intent(out) :: error
    integer :: i
    if (allocated(self%selected)) then
      do i = 1, size(self%selected)
        if (len(string_value(self%selected(i)%value)) /= len(name)) cycle
        if (string_value(self%selected(i)%value) == name) return
      end do
    end if
    error%code = 'AGENT_TOOL_NOT_SELECTED'
  end subroutine

  function advertised(self, specs) result(output)
    class(tool_selection), intent(in) :: self
    type(tool_spec), intent(in) :: specs(:)
    type(tool_spec), allocatable :: output(:), matching(:)
    type(sdk_error) :: error
    integer :: i, count
    allocate(matching(size(specs)))
    count = 0
    do i = 1, size(specs)
      call self%check(string_value(specs(i)%name), error)
      if (error%failed()) cycle
      count = count + 1
      matching(count) = specs(i)
    end do
    output = matching(:count)
  end function

  subroutine generate_fallback(self, req, res, error)
    class(fallback_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    if (.not. associated(self%primary)) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    call self%primary%generate(req, res, error)
    if (.not. error%failed()) return
    if (associated(self%fallback)) call self%fallback%generate(req, res, error)
  end subroutine

  function structured_output(schema, content, max_repairs, error, repair) result(output)
    character(*), intent(in) :: schema, content
    integer, intent(in) :: max_repairs
    type(sdk_error), intent(out) :: error
    procedure(repair_interface), optional :: repair
    character(:), allocatable :: output, current, repaired
    type(validation_error), allocatable :: errors(:)
    type(sdk_error) :: validation
    integer :: attempt
    output = ''
    current = content
    do attempt = 0, max(0, max_repairs)
      call validate_schema(schema, current, errors, validation)
      if (.not. validation%failed()) then
        if (size(errors) == 0) then
          output = current
          return
        end if
      end if
      if (attempt == max(0, max_repairs) .or. .not. present(repair)) exit
      call repair(current, errors, attempt + 1, repaired, error)
      if (error%failed()) return
      if (.not. allocated(repaired)) exit
      current = repaired
    end do
    error%code = 'AGENT_STRUCTURED_OUTPUT'
  end function

  subroutine generate_structured(self, req, res, error)
    class(structured_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: output
    if (.not. associated(self%provider) .or. .not. allocated(self%schema)) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    call self%provider%generate(req, res, error)
    if (error%failed()) return
    if (allocated(res%message%tool_calls)) then
      if (size(res%message%tool_calls) > 0) return
    end if
    if (associated(self%repair)) then
      output = structured_output(self%schema, string_value(res%message%content), self%max_repairs, error, self%repair)
    else
      output = structured_output(self%schema, string_value(res%message%content), self%max_repairs, error)
    end if
    if (.not. error%failed()) res%message%content = output
  end subroutine

  function redact_email(text) result(output)
    character(*), intent(in) :: text
    character(:), allocatable :: output
    integer :: cursor, at, first, last, dot, i, suffix
    output = ''
    cursor = 1
    do while (cursor <= len(text))
      at = index(text(cursor:), '@')
      if (at == 0) exit
      at = at + cursor - 1
      first = at
      do while (first > cursor)
        if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._%+-', text(first - 1:first - 1)) == 0) exit
        first = first - 1
      end do
      last = at + 1
      do while (last <= len(text))
        if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-', text(last:last)) == 0) exit
        last = last + 1
      end do
      dot = 0
      do i = at + 1, last - 1
        if (text(i:i) == '.') dot = i
      end do
      suffix = dot + 1
      if (dot > at + 1) then
        do while (suffix < last)
          if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', text(suffix:suffix)) == 0) exit
          suffix = suffix + 1
        end do
      end if
      if (first < at .and. dot > at + 1 .and. suffix - dot - 1 >= 2) then
        output = output//text(cursor:first - 1)//'[REDACTED:email]'
        cursor = suffix
      else
        output = output//text(cursor:at)
        cursor = at + 1
      end if
    end do
    output = output//text(cursor:)
  end function

  function redact_json_email(raw, error) result(output)
    character(*), intent(in) :: raw
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: output
    type(json_document) :: doc
    integer :: i
    output = ''
    call parse_json(raw, doc, error)
    if (error%failed()) return
    do i = 1, size(doc%nodes)
      if (json_kind(doc, i) == 'S') doc%nodes(i)%text = redact_email(json_text(doc, i))
    end do
    output = encode_json(doc, 1, error)
  end function
end module
