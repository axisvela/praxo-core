module harmovela_test_support
  use iso_fortran_env, only: int64
  use praxo_types, only: sdk_error
  use praxo_harmovela, only: harmovela_response
  implicit none
  character(:), allocatable :: captured_method, captured_url
  character(:), allocatable :: captured_content, captured_body
  integer :: transport_calls = 0
  integer :: response_status = 201
  character(:), allocatable :: response_body
contains
  subroutine fake_transport(method, url, content_type, body, response, error)
    character(*), intent(in) :: method, url, content_type, body
    type(harmovela_response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    transport_calls = transport_calls + 1
    captured_method = method
    captured_url = url
    captured_content = content_type
    captured_body = body
    response%status = response_status
    response%body = response_body
    error%code = ''
  end subroutine

  function fixed_clock() result(epoch)
    integer(int64) :: epoch
    epoch = 1794294000000000000_int64
  end function
end module

program harmovela_tests
  use praxo_types
  use praxo_harmovela
  use praxo_json
  use harmovela_test_support
  implicit none
  type(harmovela_sink) :: sink
  type(event) :: item
  type(json_document) :: document
  type(sdk_error) :: error
  integer :: checks = 0, failures = 0, i, payload
  integer, parameter :: statuses(4) = [200, 201, 204, 299]

  sink%base_url = 'http://harmovela.test/aep/api/'
  sink%source = 'praxo-core'
  sink%spec_version = '0.2'
  sink%transport => fake_transport
  sink%clock => fixed_clock
  response_body = ''

  item = event('tool.call', 's1', 'run-123', '', '')
  item%tool_name = 'echo'
  item%arguments = '{"text":"hi"}'
  call sink%emit(item)
  call check(.not. sink%failed(), 'success')
  call check(transport_calls == 1, 'single request')
  call check(captured_method == 'POST', 'method')
  call check(captured_url == 'http://harmovela.test/aep/api/events', 'path')
  call check(captured_content == 'application/json', 'content type')
  call parse_json(captured_body, document, error)
  call check(.not. error%failed(), 'envelope json')
  call check(json_text(document, json_get(document, 1, 'spec_version')) == '0.2', 'spec')
  call check(json_text(document, json_get(document, 1, 'id')) == &
    'run-123-1794294000000000000', 'id')
  call check(json_text(document, json_get(document, 1, 'type')) == 'tool.call', 'type')
  call check(json_text(document, json_get(document, 1, 'source')) == 'praxo-core', 'source')
  call check(json_text(document, json_get(document, 1, 'created_at')) == &
    '2026-11-10T07:00:00.000000000Z', 'created_at')
  payload = json_get(document, 1, 'payload')
  call check(json_text(document, json_get(document, payload, 'name')) == 'echo', 'payload name')
  call check(json_kind(document, json_get(document, payload, 'arguments')) == 'O', &
    'payload arguments')
  call check(json_text(document, json_get(document, payload, 'session_id')) == 's1', &
    'payload session')
  call check(json_text(document, json_get(document, payload, 'run_id')) == 'run-123', &
    'payload run')

  sink%source = 'custom'
  sink%spec_version = '0.3'
  item = event('tool.call', 's1', '', '', '')
  item%tool_name = 'echo'
  call sink%emit(item)
  call parse_json(captured_body, document, error)
  call check(json_text(document, json_get(document, 1, 'source')) == 'custom', 'custom source')
  call check(json_text(document, json_get(document, 1, 'spec_version')) == '0.3', 'custom spec')
  call check(index(json_text(document, json_get(document, 1, 'id')), 's1-') == 1, &
    'session id prefix')
  payload = json_get(document, 1, 'payload')
  call check(json_text(document, json_get(document, payload, 'session_id')) == 's1', &
    'session override')

  do i = 1, size(statuses)
    response_status = statuses(i)
    call sink%emit(item)
    call check(.not. sink%failed(), 'accepts 2xx')
  end do

  response_status = 503
  response_body = repeat('service down ', 100)
  call sink%emit(item)
  call check(sink%failed(), 'non-2xx fails')
  call check(sink%error_code == 'HARMOVELA_HTTP', 'non-2xx code')
  call check(index(sink%error_message, '503') > 0, 'error status')
  call check(index(sink%error_message, 'service down') > 0, 'error body')
  call check(len(sink%error_message) <= 600, 'bounded error')

  response_status = 201
  response_body = ''
  if (failures == 0) then
    write(*, '(a,i0,a)') 'fortran harmovela tests passed (', checks, ' checks)'
  else
    write(*, '(a,i0,a,i0,a)') 'fortran harmovela tests failed (', failures, &
      ' of ', checks, ' checks)'
    error stop 1
  end if
contains
  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(*), intent(in) :: message
    checks = checks + 1
    if (.not. condition) then
      failures = failures + 1
      write(*, '(a)') 'FAIL '//trim(message)
    end if
  end subroutine
end program
