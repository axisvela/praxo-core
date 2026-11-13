module fake_delegation
  use praxo_types, only: sdk_error
  use praxo_delegation, only: subagent_request, subagent_result
  implicit none
contains
  subroutine success_runner(request, result, error)
    type(subagent_request), intent(in) :: request
    type(subagent_result), intent(out) :: result
    type(sdk_error), intent(out) :: error
    result%task_id = request%agent_id
    result%output = 'done'
    error%code = ''
  end subroutine

  subroutine failure_runner(request, result, error)
    type(subagent_request), intent(in) :: request
    type(subagent_result), intent(out) :: result
    type(sdk_error), intent(out) :: error
    result%task_id = request%agent_id
    result%output = ''
    error%code = 'boom'
  end subroutine
end module

program delegation_tests
  use praxo_types, only: sdk_error
  use praxo_delegation
  use fake_delegation
  implicit none
  type(subagent_request) :: request
  type(subagent_task) :: task
  type(sdk_error) :: error
  request = subagent_request_new('parent', 'child', 'do', 'fork')
  task = subagent_run(success_runner, request, error)
  if (error%failed()) error stop 1
  if (task%status /= 'completed') error stop 2
  if (task%output /= 'done') error stop 3
  if (task%mode /= 'fork') error stop 4

  task = subagent_run(failure_runner, request, error)
  if (task%status /= 'failed') error stop 5
  if (task%error /= 'boom') error stop 6

  request = subagent_request_new('', 'child', 'do')
  task = subagent_run(success_runner, request, error)
  if (error%code /= 'SUBAGENT_INVALID') error stop 7
end program
