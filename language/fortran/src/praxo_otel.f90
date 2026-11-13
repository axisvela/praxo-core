module praxo_otel
  use iso_fortran_env, only: int32, int64
  use praxo_types, only: sdk_error, event, string_value
  implicit none
  private
  public :: otel_response, otel_transport, otel_sink, otel_sink_new

  type :: otel_response
    integer :: status = 0
    character(:), allocatable :: body
  end type

  abstract interface
    subroutine otel_transport(method, url, content_type, body, response, error)
      import otel_response, sdk_error
      character(*), intent(in) :: method, url, content_type, body
      type(otel_response), intent(out) :: response
      type(sdk_error), intent(out) :: error
    end subroutine
  end interface

  type :: otel_sink
    character(:), allocatable :: endpoint
    character(:), allocatable :: service_name
    character(:), allocatable :: allowed_data_keys(:)
    character(:), allocatable :: error_code
    character(:), allocatable :: error_message
    procedure(otel_transport), pointer, nopass :: transport => null()
  contains
    procedure :: emit => emit_otel
    procedure :: failed => failed_otel
  end type
contains
  function otel_sink_new(endpoint, service_name, transport) result(sink)
    character(*), intent(in), optional :: endpoint, service_name
    procedure(otel_transport) :: transport
    type(otel_sink) :: sink
    if (present(endpoint)) then
      sink%endpoint = endpoint
    else
      sink%endpoint = 'http://127.0.0.1:4318/v1/traces'
    end if
    if (present(service_name)) then
      sink%service_name = service_name
    else
      sink%service_name = 'praxo-core'
    end if
    allocate(character(0) :: sink%allowed_data_keys(0))
    sink%transport => transport
  end function

  subroutine emit_otel(self, item)
    class(otel_sink), intent(inout) :: self
    type(event), intent(in) :: item
    type(otel_response) :: response
    type(sdk_error) :: error
    character(:), allocatable :: payload
    self%error_code = ''
    self%error_message = ''
    if (.not. associated(self%transport)) then
      call set_error(self, 'OTEL_TRANSPORT', 'otel: transport is required')
      return
    end if
    payload = build_payload(self, item)
    call self%transport('POST', self%endpoint, 'application/json', payload, &
      response, error)
    if (error%failed()) then
      call set_error(self, 'OTEL_TRANSPORT', 'otel: transport failed')
      return
    end if
    if (response%status < 200 .or. response%status >= 300) then
      call set_error(self, 'OTEL_HTTP', 'otel: HTTP '// &
        int_text(response%status)//': '//bounded(string_value(response%body)))
    end if
  end subroutine

  function build_payload(self, item) result(payload)
    class(otel_sink), intent(in) :: self
    type(event), intent(in) :: item
    character(:), allocatable :: payload, stamp, key
    character(:), allocatable :: attributes, trace_text, span_text
    character(8) :: date_value
    character(10) :: time_value
    integer :: i
    call date_and_time(date=date_value, time=time_value)
    stamp = date_value(1:4)//'-'//date_value(5:6)//'-'//date_value(7:8)//'T'// &
      time_value(1:2)//':'//time_value(3:4)//':'//time_value(5:6)//'Z'
    key = string_value(item%session_id)//'|'//string_value(item%run_id)//'|'// &
      string_value(item%kind)//'|'//stamp
    trace_text = hex32(fnv32(key, 2166136261_int64))// &
      hex32(fnv32(key, 3307539480_int64))
    span_text = hex32(fnv32(key//'|span', 2166136261_int64))// &
      hex32(fnv32(key//'|span', 3307539480_int64))
    attributes = '[{"key":"praxo.event.type","value":{"stringValue":'// &
      quote(string_value(item%kind))//'}}'
    if (len_trim(string_value(item%session_id)) > 0) then
      attributes = attributes//',{"key":"praxo.session.id",'// &
        '"value":{"stringValue":'//quote(item%session_id)//'}}'
    end if
    if (len_trim(string_value(item%run_id)) > 0) then
      attributes = attributes//',{"key":"praxo.run.id",'// &
        '"value":{"stringValue":'//quote(item%run_id)//'}}'
    end if
    attributes = attributes//',{"key":"praxo.event.at","value":'// &
      '{"stringValue":'//quote(stamp)//'}}'
    do i = 1, size(self%allowed_data_keys)
      if (self%allowed_data_keys(i) == 'tool' .and. &
          len_trim(string_value(item%tool_name)) > 0) then
        attributes = attributes//',{"key":"praxo.event.data.tool",'// &
          '"value":{"stringValue":'//quote(item%tool_name)//'}}'
      else if (self%allowed_data_keys(i) == 'arguments' .and. &
          len_trim(string_value(item%arguments)) > 0) then
        attributes = attributes//',{"key":"praxo.event.data.arguments",'// &
          '"value":{"stringValue":'//quote(item%arguments)//'}}'
      end if
    end do
    attributes = attributes//']'
    payload = '{"resourceSpans":[{"resource":{"attributes":[{"key":'// &
      '"service.name","value":{"stringValue":'//quote(self%service_name)// &
      '}}]},"scopeSpans":[{"scope":{"name":"praxo-core"},"spans":[{"traceId":"'// &
      trace_text//'","spanId":"'//span_text//'","name":'// &
      quote('praxo.'//string_value(item%kind))//',"kind":1,'// &
      '"startTimeUnixNano":"0","endTimeUnixNano":"0","attributes":'// &
      attributes//'}]}]}]}'
  end function

  logical function failed_otel(self) result(failed)
    class(otel_sink), intent(in) :: self
    failed = len_trim(self%error_code) > 0
  end function

  subroutine set_error(self, code, message)
    class(otel_sink), intent(inout) :: self
    character(*), intent(in) :: code, message
    self%error_code = code
    self%error_message = message
  end subroutine

  function fnv32(text, seed) result(value)
    character(*), intent(in) :: text
    integer(int64), intent(in) :: seed
    integer(int64) :: value
    integer :: i
    value = seed
    do i = 1, len(text)
      value = ieor(value, int(iachar(text(i:i)), int64))
      value = mod(value * 16777619_int64, 4294967296_int64)
    end do
  end function

  function hex32(value) result(text)
    integer(int64), intent(in) :: value
    character(8) :: text
    write(text, '(z8.8)') int(value, int32)
  end function

  function quote(value) result(text)
    character(*), intent(in) :: value
    character(:), allocatable :: text
    integer :: i
    text = '"'
    do i = 1, len(value)
      select case (value(i:i))
      case ('"')
        text = text//'\"'
      case ('\')
        text = text//'\\'
      case default
        text = text//value(i:i)
      end select
    end do
    text = text//'"'
  end function

  function int_text(value) result(text)
    integer, intent(in) :: value
    character(:), allocatable :: text
    character(16) :: buffer
    write(buffer, '(i0)') value
    text = trim(buffer)
  end function

  function bounded(value) result(text)
    character(*), intent(in) :: value
    character(:), allocatable :: text
    text = value(1:min(len(value), 512))
  end function
end module
