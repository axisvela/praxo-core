program service_example
  implicit none
  integer :: status
  character(:), allocatable :: body

  call handle('GET', '/healthz', '', '', status, body)
  if (status /= 200 .or. index(body, '"ok"') == 0) stop 1

  call handle('POST', '/run', '', '{"prompt":"hi"}', status, body)
  if (status /= 401) stop 1

  call handle('POST', '/run', 'user-1', '{"prompt":"hi"}', status, body)
  if (status /= 200 .or. index(body, 'hello from the service') == 0) stop 1

  print '(a)', 'Fortran service example passed'
contains
  subroutine handle(method, path, principal, body, status, response)
    character(*), intent(in) :: method, path, principal, body
    integer, intent(out) :: status
    character(:), allocatable, intent(out) :: response
    if (method == 'GET' .and. path == '/healthz') then
      status = 200
      response = '{"status":"ok"}'
      return
    end if
    if (method /= 'POST' .or. path /= '/run') then
      status = 404
      response = '{"error":"not found"}'
      return
    end if
    if (len_trim(principal) == 0) then
      status = 401
      response = '{"error":"missing X-Praxo-Principal"}'
      return
    end if
    if (index(body, '"prompt"') == 0) then
      status = 400
      response = '{"error":"prompt is required"}'
      return
    end if
    status = 200
    response = '{"output":"hello from the service"}'
  end subroutine
end program
