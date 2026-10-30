module praxo_stream
  implicit none
  private
  public :: stream_part, stream_kinds
  character(10), parameter :: stream_kinds(6) = &
    [character(10) :: 'values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint']

  type :: stream_part
    character(:), allocatable :: run_id, session_id, kind, data, at
    integer :: step = 0
  end type
end module
