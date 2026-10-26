module praxo_context
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_json
  implicit none
  private
  public :: context_budget, estimate_tokens

  type :: context_budget
    integer(int64) :: max_tokens = 0
    integer :: keep_recent = 0
  contains
    procedure :: compact
  end type
contains
  function estimate_tokens(messages) result(tokens)
    type(message), intent(in) :: messages(:)
    integer(int64) :: tokens
    integer :: i, j
    character(:), allocatable :: arguments
    type(json_document) :: doc
    type(sdk_error) :: error
    tokens = 0
    do i = 1, size(messages)
      tokens = tokens + 4 + len(string_value(messages(i)%content)) / 4 &
        + len(string_value(messages(i)%tool_call_id)) / 4
      if (.not. allocated(messages(i)%tool_calls)) cycle
      do j = 1, size(messages(i)%tool_calls)
        arguments = 'null'
        if (allocated(messages(i)%tool_calls(j)%arguments)) arguments = messages(i)%tool_calls(j)%arguments
        call parse_json(arguments, doc, error)
        if (.not. error%failed()) arguments = encode_json(doc, 1, error)
        tokens = tokens + 4 + len(string_value(messages(i)%tool_calls(j)%name)) / 4 + len(arguments) / 4
      end do
    end do
  end function

  subroutine compact(self, messages, output, ok)
    class(context_budget), intent(in) :: self
    type(message), intent(in) :: messages(:)
    type(message), allocatable, intent(out) :: output(:)
    logical, intent(out) :: ok
    type(message), allocatable :: system(:), rest(:)
    type(message) :: marker
    integer :: i, system_count, rest_count, keep, first, omitted, count
    integer(int64) :: available
    character(:), allocatable :: content
    character(32) :: digits

    ok = .true.
    output = messages
    if (self%max_tokens <= 0) return
    if (estimate_tokens(messages) <= self%max_tokens) return
    allocate(system(size(messages)), rest(size(messages)))
    system_count = 0
    rest_count = 0
    do i = 1, size(messages)
      if (string_value(messages(i)%role) == 'system') then
        if (index(string_value(messages(i)%content), '[context compacted:') == 1) cycle
        system_count = system_count + 1
        system(system_count) = messages(i)
      else
        rest_count = rest_count + 1
        rest(rest_count) = messages(i)
      end if
    end do
    if (estimate_tokens(system(:system_count)) > self%max_tokens) then
      if (system_count == 0) then
        call fail()
        return
      end if
      system_count = 1
      content = string_value(system(1)%content)
      available = max(0_int64, self%max_tokens - 4)
      if (available < (len(content) + 3_int64) / 4) then
        count = int(available * 4)
        if (count <= 16) then
          content = content(:count)
        else
          content = content(:count - 16)//achar(10)//'[truncated]'
        end if
      end if
      system(1)%content = content
      if (estimate_tokens(system(:system_count)) > self%max_tokens) then
        call fail()
        return
      end if
    end if
    keep = self%keep_recent
    if (keep <= 0) keep = 4
    first = max(1, rest_count - keep + 1)
    do while (first > 1)
      if (string_value(rest(first)%role) /= 'tool') exit
      first = first - 1
    end do
    omitted = first - 1
    write(digits, '(i0)') omitted
    marker = text_message('system', '[context compacted: '//trim(digits)//' older messages omitted]')
    call build()
    do while (estimate_tokens(output) > self%max_tokens .and. rest_count - first + 1 > 1)
      if (string_value(rest(first + 1)%role) == 'tool') exit
      first = first + 1
      call build()
    end do
    if (estimate_tokens(output) > self%max_tokens) call fail()
  contains
    subroutine build()
      integer :: marker_count
      marker_count = 0
      if (omitted > 0) marker_count = 1
      if (allocated(output)) deallocate(output)
      allocate(output(system_count + marker_count + rest_count - first + 1))
      output(:system_count) = system(:system_count)
      if (marker_count == 1) output(system_count + 1) = marker
      output(system_count + marker_count + 1:) = rest(first:rest_count)
    end subroutine

    subroutine fail()
      ok = .false.
      if (allocated(output)) deallocate(output)
      allocate(output(0))
    end subroutine
  end subroutine
end module
