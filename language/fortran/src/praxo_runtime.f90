module praxo_runtime
  use praxo_types
  use praxo_interfaces, only: event_sink
  implicit none
  private
  public :: recording_sink, filter_sink, multi_sink, memory_record, memory_store

  type, extends(event_sink) :: recording_sink
    type(event), allocatable :: items(:)
  contains
    procedure :: emit => record_event
  end type

  type, extends(event_sink) :: filter_sink
    class(event_sink), pointer :: target => null()
    character(:), allocatable :: kinds(:)
  contains
    procedure :: emit => filter_event
  end type

  type :: sink_entry
    class(event_sink), pointer :: target => null()
  end type

  type, extends(event_sink) :: multi_sink
    private
    type(sink_entry), allocatable :: entries(:)
  contains
    procedure :: add => add_sink
    procedure :: emit => multicast_event
  end type

  type :: memory_record
    character(:), allocatable :: id, frame, content, created_at
  end type

  type :: memory_entry
    character(:), allocatable :: session_id
    type(memory_record) :: record
  end type

  type :: memory_store
    private
    type(memory_entry), allocatable :: entries(:)
  contains
    procedure :: put => put_memory
    procedure :: search => search_memory
  end type
contains
  subroutine record_event(self, item)
    class(recording_sink), intent(inout) :: self
    type(event), intent(in) :: item
    type(event), allocatable :: expanded(:)
    integer :: count
    count = 0
    if (allocated(self%items)) count = size(self%items)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = self%items
    expanded(count + 1) = item
    call move_alloc(expanded, self%items)
  end subroutine

  subroutine filter_event(self, item)
    class(filter_sink), intent(inout) :: self
    type(event), intent(in) :: item
    if (.not. associated(self%target)) return
    if (allocated(self%kinds)) then
      if (.not. any(self%kinds == string_value(item%kind))) return
    end if
    call self%target%emit(item)
  end subroutine

  subroutine add_sink(self, target)
    class(multi_sink), intent(inout) :: self
    class(event_sink), target, intent(inout) :: target
    type(sink_entry), allocatable :: expanded(:)
    integer :: count
    count = 0
    if (allocated(self%entries)) count = size(self%entries)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = self%entries
    expanded(count + 1)%target => target
    call move_alloc(expanded, self%entries)
  end subroutine

  subroutine multicast_event(self, item)
    class(multi_sink), intent(inout) :: self
    type(event), intent(in) :: item
    integer :: i
    if (.not. allocated(self%entries)) return
    do i = 1, size(self%entries)
      call self%entries(i)%target%emit(item)
    end do
  end subroutine

  subroutine put_memory(self, session_id, record)
    class(memory_store), intent(inout) :: self
    character(*), intent(in) :: session_id
    type(memory_record), intent(in) :: record
    type(memory_entry), allocatable :: expanded(:)
    integer :: count
    count = 0
    if (allocated(self%entries)) count = size(self%entries)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = self%entries
    expanded(count + 1) = memory_entry(session_id, record)
    call move_alloc(expanded, self%entries)
  end subroutine

  function search_memory(self, session_id, query, limit) result(records)
    class(memory_store), intent(in) :: self
    character(*), intent(in) :: session_id, query
    integer, intent(in) :: limit
    type(memory_record), allocatable :: records(:), matching(:)
    type(memory_record) :: temporary
    integer :: i, j, count
    allocate(records(0))
    if (.not. allocated(self%entries)) return
    allocate(matching(size(self%entries)))
    count = 0
    do i = 1, size(self%entries)
      if (.not. same_string(self%entries(i)%session_id, session_id)) cycle
      if (index(ascii_lower(string_value(self%entries(i)%record%content)), ascii_lower(query)) == 0) cycle
      count = count + 1
      matching(count) = self%entries(i)%record
    end do
    do i = 2, count
      j = i
      do while (j > 1)
        if (string_value(matching(j - 1)%created_at) >= string_value(matching(j)%created_at)) exit
        temporary = matching(j - 1)
        matching(j - 1) = matching(j)
        matching(j) = temporary
        j = j - 1
      end do
    end do
    if (limit > 0) count = min(count, limit)
    records = matching(:count)
  end function

  function ascii_lower(text) result(lower)
    character(*), intent(in) :: text
    character(len(text)) :: lower
    integer :: i, code
    lower = text
    do i = 1, len(text)
      code = iachar(text(i:i))
      if (code >= 65 .and. code <= 90) lower(i:i) = achar(code + 32)
    end do
  end function
end module
