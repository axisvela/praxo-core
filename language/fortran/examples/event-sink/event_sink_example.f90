program event_sink_example
  use praxo_types
  use praxo_runtime
  implicit none
  type(recording_sink), target :: all, tool
  type(filter_sink) :: filtered
  type(multi_sink) :: multi
  type(event) :: item

  filtered%target => tool
  filtered%kinds = [character(32) :: 'tool.call']
  call multi%add(all)
  call multi%add(filtered)

  item%kind = 'run.started'
  call multi%emit(item)
  item%kind = 'tool.call'
  call multi%emit(item)
  item%kind = 'run.completed'
  call multi%emit(item)

  if (size(all%items) /= 3) stop 1
  if (all%items(1)%kind /= 'run.started') stop 1
  if (all%items(2)%kind /= 'tool.call') stop 1
  if (all%items(3)%kind /= 'run.completed') stop 1
  if (size(tool%items) /= 1 .or. tool%items(1)%kind /= 'tool.call') stop 1

  print '(a)', 'Fortran event sink example passed'
end program
