module praxo_harmovela
  use iso_fortran_env, only: int64
  use praxo_types, only: sdk_error, event, string_value
  use praxo_interfaces, only: event_sink
  use praxo_json, only: json_document, parse_json, json_kind
  implicit none
  private
  public :: harmovela_response, harmovela_transport, harmovela_clock
  public :: harmovela_sink

  type :: harmovela_response
    integer :: status = 0
    character(:), allocatable :: body
  end type

  abstract interface
    subroutine harmovela_transport(method, url, content_type, body, response, error)
      import harmovela_response, sdk_error
      character(*), intent(in) :: method, url, content_type, body
      type(harmovela_response), intent(out) :: response
      type(sdk_error), intent(out) :: error
    end subroutine

    function harmovela_clock() result(epoch_nanos)
      import int64
      integer(int64) :: epoch_nanos
    end function
  end interface

  type, extends(event_sink) :: harmovela_sink
    character(:), allocatable :: base_url
    character(:), allocatable :: source
    character(:), allocatable :: spec_version
    character(:), allocatable :: error_code
    character(:), allocatable :: error_message
    procedure(harmovela_transport), pointer, nopass :: transport => null()
    procedure(harmovela_clock), pointer, nopass :: clock => null()
  contains
    procedure :: emit => emit_harmovela
    procedure :: envelope => envelope_harmovela
    procedure :: failed => failed_harmovela
  end type
contains
  subroutine emit_harmovela(self, item)
    class(harmovela_sink), intent(inout) :: self
    type(event), intent(in) :: item
    type(harmovela_response) :: response
    type(sdk_error) :: error
    character(:), allocatable :: body, url
    self%error_code = ''
    self%error_message = ''
    if (.not. allocated(self%base_url)) then
      call set_error(self, 'HARMOVELA_BASE_URL', 'harmovela: base URL is required')
      return
    end if
    if (len_trim(self%base_url) == 0) then
      call set_error(self, 'HARMOVELA_BASE_URL', 'harmovela: base URL is required')
      return
    end if
    body = self%envelope(item)
    if (len(body) == 0) then
      call set_error(self, 'HARMOVELA_JSON', 'harmovela: cannot encode envelope')
      return
    end if
    url = trim_trailing(self%base_url)//'/events'
    if (.not. associated(self%transport)) then
      call set_error(self, 'HARMOVELA_TRANSPORT', &
        'harmovela: inject a transport; no HTTP client is bundled')
      return
    end if
    call self%transport('POST', url, 'application/json', body, response, error)
    if (error%failed()) then
      call set_error(self, 'HARMOVELA_TRANSPORT', &
        'harmovela: transport failed: '//string_value(error%code))
      return
    end if
    if (response%status < 200 .or. response%status >= 300) then
      call set_error(self, 'HARMOVELA_HTTP', 'harmovela: HTTP '// &
        int_text(int(response%status, int64))//': '//bounded(string_value(response%body), 512))
    end if
  end subroutine

  function envelope_harmovela(self, item) result(body)
    class(harmovela_sink), intent(in) :: self
    type(event), intent(in) :: item
    character(:), allocatable :: body, source, spec, created, identifier, prefix
    character(:), allocatable :: payload
    type(sdk_error) :: error
    type(json_document) :: document
    integer(int64) :: epoch
    logical :: first
    if (associated(self%clock)) then
      epoch = self%clock()
    else
      call default_clock(epoch)
    end if
    created = format_epoch(epoch)
    source = string_value(self%source)
    if (len_trim(source) == 0) source = 'praxo-core'
    spec = string_value(self%spec_version)
    if (len_trim(spec) == 0) spec = '0.2'
    prefix = 'event'
    if (allocated(item%run_id)) then
      if (len_trim(item%run_id) > 0) then
        prefix = item%run_id
      else if (allocated(item%session_id)) then
        if (len_trim(item%session_id) > 0) prefix = item%session_id
      end if
    else if (allocated(item%session_id)) then
      if (len_trim(item%session_id) > 0) prefix = item%session_id
    end if
    identifier = prefix//'-'//int_text(epoch)
    payload = '{'
    first = .true.
    if (allocated(item%tool_name)) then
      if (len_trim(item%tool_name) > 0) then
        payload = payload//'"name":'//quote(item%tool_name)
        first = .false.
      end if
    end if
    if (allocated(item%arguments)) then
      if (len_trim(item%arguments) > 0) then
        if (.not. first) payload = payload//','
        call parse_json(item%arguments, document, error)
        if (.not. error%failed()) then
          if (json_kind(document, 1) == 'O' .or. json_kind(document, 1) == 'A') then
            payload = payload//'"arguments":'//item%arguments
          else
            payload = payload//'"arguments":'//quote(item%arguments)
          end if
        else
          payload = payload//'"arguments":'//quote(item%arguments)
        end if
        first = .false.
      end if
    end if
    if (allocated(item%session_id)) then
      if (len_trim(item%session_id) > 0) then
        if (.not. first) payload = payload//','
        payload = payload//'"session_id":'//quote(item%session_id)
        first = .false.
      end if
    end if
    if (allocated(item%run_id)) then
      if (len_trim(item%run_id) > 0) then
        if (.not. first) payload = payload//','
        payload = payload//'"run_id":'//quote(item%run_id)
      end if
    end if
    payload = payload//'}'
    body = '{"spec_version":'//quote(spec)//',"id":'//quote(identifier)// &
      ',"type":'//quote(string_value(item%kind))//',"source":'//quote(source)// &
      ',"created_at":'//quote(created)//',"payload":'//payload//'}'
  end function

  logical function failed_harmovela(self) result(failed)
    class(harmovela_sink), intent(in) :: self
    failed = .false.
    if (allocated(self%error_code)) failed = len(self%error_code) > 0
  end function

  subroutine set_error(self, code, message)
    class(harmovela_sink), intent(inout) :: self
    character(*), intent(in) :: code, message
    self%error_code = code
    self%error_message = message
  end subroutine

  function trim_trailing(text) result(output)
    character(*), intent(in) :: text
    character(:), allocatable :: output
    integer :: last
    last = len_trim(text)
    do while (last > 0)
      if (text(last:last) /= '/') exit
      last = last - 1
    end do
    output = text(:last)
  end function

  function bounded(text, limit) result(output)
    character(*), intent(in) :: text
    integer, intent(in) :: limit
    character(:), allocatable :: output
    if (len(text) > limit) then
      output = text(:limit)
    else
      output = text
    end if
  end function

  function int_text(value) result(text)
    integer(int64), intent(in) :: value
    character(:), allocatable :: text
    character(len=32) :: buffer
    write(buffer, '(i0)') value
    text = trim(buffer)
  end function

  function quote(text) result(output)
    character(*), intent(in) :: text
    character(:), allocatable :: output
    character(len=6) :: escape
    integer :: i, code
    output = '"'
    do i = 1, len(text)
      code = iachar(text(i:i))
      select case (code)
      case (34)
        output = output//'\"'
      case (92)
        output = output//'\\'
      case (8)
        output = output//'\b'
      case (12)
        output = output//'\f'
      case (10)
        output = output//'\n'
      case (13)
        output = output//'\r'
      case (9)
        output = output//'\t'
      case default
        if (code < 32) then
          write(escape, '(a,i4.4)') '\u', code
          output = output//escape
        else
          output = output//text(i:i)
        end if
      end select
    end do
    output = output//'"'
  end function

  subroutine default_clock(epoch)
    integer(int64), intent(out) :: epoch
    integer :: values(8)
    integer(int64) :: days, seconds
    call date_and_time(values=values)
    days = days_from_civil(int(values(1), int64), int(values(2), int64), &
      int(values(3), int64))
    seconds = days*86400_int64 + int(values(5), int64)*3600_int64 + &
      int(values(6), int64)*60_int64 + int(values(7), int64)
    seconds = seconds - int(values(4), int64)*60_int64
    epoch = seconds*1000000000_int64 + int(values(8), int64)*1000000_int64
  end subroutine

  function format_epoch(epoch) result(text)
    integer(int64), intent(in) :: epoch
    character(:), allocatable :: text
    integer(int64) :: seconds, days, day_seconds, year, month, day
    integer(int64) :: hour, minute, second, nanos
    character(len=4) :: year_text
    character(len=2) :: month_text, day_text, hour_text, minute_text, second_text
    character(len=9) :: nanos_text
    seconds = epoch/1000000000_int64
    nanos = mod(epoch, 1000000000_int64)
    days = seconds/86400_int64
    day_seconds = mod(seconds, 86400_int64)
    call civil_from_days(days, year, month, day)
    hour = day_seconds/3600_int64
    minute = mod(day_seconds, 3600_int64)/60_int64
    second = mod(day_seconds, 60_int64)
    write(year_text, '(i4.4)') int(year)
    write(month_text, '(i2.2)') int(month)
    write(day_text, '(i2.2)') int(day)
    write(hour_text, '(i2.2)') int(hour)
    write(minute_text, '(i2.2)') int(minute)
    write(second_text, '(i2.2)') int(second)
    write(nanos_text, '(i9.9)') int(nanos)
    text = year_text//'-'//month_text//'-'//day_text//'T'//hour_text//':'// &
      minute_text//':'//second_text//'.'//nanos_text//'Z'
  end function

  function days_from_civil(year, month, day) result(days)
    integer(int64), intent(in) :: year, month, day
    integer(int64) :: days, y, era, yoe, doy, doe, mp
    y = merge(year - 1, year, month <= 2)
    era = merge(y/400, (y - 399)/400, y >= 0)
    yoe = y - era*400
    mp = merge(month - 3, month + 9, month > 2)
    doy = (153*mp + 2)/5 + day - 1
    doe = yoe*365 + yoe/4 - yoe/100 + doy
    days = era*146097 + doe - 719468
  end function

  subroutine civil_from_days(days, year, month, day)
    integer(int64), intent(in) :: days
    integer(int64), intent(out) :: year, month, day
    integer(int64) :: z, era, doe, yoe, doy, mp
    z = days + 719468
    era = merge(z/146097, (z - 146096)/146097, z >= 0)
    doe = z - era*146097
    yoe = (doe - doe/1460 + doe/36524 - doe/146096)/365
    year = yoe + era*400
    doy = doe - (365*yoe + yoe/4 - yoe/100)
    mp = (5*doy + 2)/153
    day = doy - (153*mp + 2)/5 + 1
    month = merge(mp + 3, mp - 9, mp < 10)
    year = merge(year + 1, year, month <= 2)
  end subroutine
end module
