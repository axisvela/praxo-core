module praxo_delegation
  use praxo_types, only: sdk_error
  implicit none
  private
  public :: subagent_request, subagent_result, subagent_task
  public :: subagent_runner, subagent_request_new, subagent_run

  type :: subagent_request
    character(:), allocatable :: parent_session_id
    character(:), allocatable :: agent_id
    character(:), allocatable :: prompt
    character(:), allocatable :: mode
  end type

  type :: subagent_result
    character(:), allocatable :: task_id
    character(:), allocatable :: agent_id
    character(:), allocatable :: output
  end type

  type :: subagent_task
    character(:), allocatable :: id
    character(:), allocatable :: parent_session_id
    character(:), allocatable :: agent_id
    character(:), allocatable :: mode
    character(:), allocatable :: status
    character(:), allocatable :: output
    character(:), allocatable :: error
    character(:), allocatable :: created_at
    character(:), allocatable :: updated_at
  end type

  abstract interface
    subroutine subagent_runner(request, result, error)
      import subagent_request, subagent_result, sdk_error
      type(subagent_request), intent(in) :: request
      type(subagent_result), intent(out) :: result
      type(sdk_error), intent(out) :: error
    end subroutine
  end interface
contains
  function subagent_request_new(parent_session_id, agent_id, prompt, mode) &
      result(request)
    character(*), intent(in) :: parent_session_id, agent_id, prompt
    character(*), intent(in), optional :: mode
    type(subagent_request) :: request
    request%parent_session_id = parent_session_id
    request%agent_id = agent_id
    request%prompt = prompt
    request%mode = 'isolated'
    if (present(mode)) then
      if (mode == 'fork') request%mode = 'fork'
    end if
  end function

  function subagent_run(runner, request, error) result(task)
    procedure(subagent_runner) :: runner
    type(subagent_request), intent(in) :: request
    type(sdk_error), intent(out) :: error
    type(subagent_task) :: task
    type(subagent_result) :: result
    error%code = ''
    task%id = 'subagent-0'
    task%parent_session_id = request%parent_session_id
    task%agent_id = request%agent_id
    task%mode = request%mode
    task%status = 'running'
    task%output = ''
    task%error = ''
    task%created_at = timestamp()
    task%updated_at = task%created_at
    if (len_trim(request%parent_session_id) == 0 .or. &
        len_trim(request%agent_id) == 0) then
      error%code = 'SUBAGENT_INVALID'
      return
    end if
    call runner(request, result, error)
    if (error%failed()) then
      task%status = 'failed'
      task%error = error%code
    else
      task%status = 'completed'
      task%output = result%output
    end if
    task%updated_at = timestamp()
  end function

  function timestamp() result(text)
    character(8) :: date_value
    character(10) :: time_value
    character(:), allocatable :: text
    call date_and_time(date=date_value, time=time_value)
    text = date_value(1:4)//'-'//date_value(5:6)//'-'//date_value(7:8)//'T'// &
      time_value(1:2)//':'//time_value(3:4)//':'//time_value(5:6)//'Z'
  end function
end module
