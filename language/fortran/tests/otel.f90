module fake_otel
  use praxo_types, only: sdk_error
  use praxo_otel, only: otel_response
  implicit none
  character(:), allocatable :: otel_body
contains
  subroutine otel_capture(method, url, content_type, body, response, error)
    character(*), intent(in) :: method, url, content_type, body
    type(otel_response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    otel_body = body
    if (len(method) == 0 .or. len(url) == 0 .or. len(content_type) == 0) response%status = 500
    response%status = 200
    response%body = ''
    error%code = ''
  end subroutine

  subroutine otel_fail(method, url, content_type, body, response, error)
    character(*), intent(in) :: method, url, content_type, body
    type(otel_response), intent(out) :: response
    type(sdk_error), intent(out) :: error
    if (len(method) == 0 .or. len(url) == 0 .or. len(content_type) == 0) response%status = 500
    if (len(body) == 0) response%status = 500
    response%status = 503
    response%body = 'down'
    error%code = ''
  end subroutine
end module

program otel_tests
  use praxo_types, only: event
  use praxo_otel
  use fake_otel
  implicit none
  type(otel_sink) :: sink
  type(event) :: item

  sink = otel_sink_new('http://otel.test/v1/traces', 'praxo-test', otel_capture)
  if (allocated(sink%allowed_data_keys)) deallocate(sink%allowed_data_keys)
  allocate(character(4) :: sink%allowed_data_keys(1))
  sink%allowed_data_keys(1) = 'tool'
  item%kind = 'tool.call'
  item%session_id = 's1'
  item%run_id = 'run-123'
  item%tool_name = 'echo'
  item%arguments = '{}'
  call sink%emit(item)
  if (sink%failed()) error stop 1
  if (index(otel_body, '"name":"praxo.tool.call"') == 0) error stop 2
  if (index(otel_body, 'praxo.event.data.tool') == 0) error stop 3
  if (index(otel_body, '"traceId":"') == 0) error stop 4
  if (index(otel_body, '"service.name"') == 0) error stop 5

  sink = otel_sink_new('http://otel.test/v1/traces', 'praxo-test', otel_fail)
  call sink%emit(item)
  if (.not. sink%failed()) error stop 6
  if (sink%error_code /= 'OTEL_HTTP') error stop 7
end program
