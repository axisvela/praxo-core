module streaming_example_types
  use praxo_types
  use praxo_interfaces
  use praxo_stream, only: stream_part
  implicit none
  integer :: part_count = 0
  character(16) :: part_kinds(2)

  type, extends(model) :: simple_model
  contains
    procedure :: generate => generate_done
  end type
contains
  subroutine generate_done(self, request, response, error)
    class(simple_model), intent(inout) :: self
    type(request), intent(in) :: request
    type(response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    response%message%role = 'assistant'
    response%message%content = 'done'
  end subroutine

  subroutine capture(ctx, part, error)
    class(*), pointer, intent(in) :: ctx
    type(stream_part), intent(in) :: part
    type(sdk_error), intent(inout) :: error
    part_count = part_count + 1
    if (part_count <= 2) part_kinds(part_count) = part%kind
  end subroutine
end module

program streaming_example
  use praxo_types
  use praxo_agent
  use streaming_example_types
  implicit none
  type(simple_model), target :: model_instance
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error

  options%provider => model_instance
  options%on_stream => capture
  state%id = 'streaming'
  call run_agent(options, state, 'go', 'streaming-run', result, error)
  if (error%failed()) stop 1
  if (result%output /= 'done') stop 1
  if (part_count /= 2) stop 1
  if (part_kinds(1) /= 'values' .or. part_kinds(2) /= 'messages') stop 1
  print '(a)', 'Fortran streaming example passed'
end program
