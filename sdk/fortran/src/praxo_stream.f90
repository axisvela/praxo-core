module praxo_stream
  implicit none
  private
  public :: stream_part, stream_kinds
  character(10), parameter :: stream_kinds(6) = &
    [character(10) :: 'values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint']

  type :: stream_part
    character(:), allocatable :: kind, data
  end type
end module
