program plugin_process_test
  use praxo_plugin_process
  implicit none
  type(plugin_process_host) :: host
  character(len=256) :: python
  integer :: python_length
  character(len=:), allocatable :: error, response
  character(len=64) :: args(1)
  integer :: status

  python = 'python3'
  call get_environment_variable('PYTHON', python, length=python_length)
  args(1) = 'tests/fixtures/process_plugin.py'
  call plugin_process_start(host, 'com.example.echo', trim(python), args, &
    status=status, error=error)
  if (status /= 0) then
    write(*, '(a)') 'FAIL start: '//error
    error stop 1
  end if
  call plugin_process_invoke(host, 'tool.provider', 'echo', '{"text":"hi"}', &
    response, status, error)
  if (status /= 0 .or. response /= '{"text":"hi"}') then
    write(*, '(a)') 'FAIL echo: '//error
    error stop 1
  end if
  call plugin_process_invoke(host, 'tool.provider', 'denied', '', &
    response, status, error)
  if (status == 0 .or. error /= 'CAPABILITY_DENIED') then
    write(*, '(a)') 'FAIL denied: '//error
    error stop 1
  end if
  call plugin_process_stop(host)
  write(*, '(a)') 'fortran plugin process tests passed'
end program
