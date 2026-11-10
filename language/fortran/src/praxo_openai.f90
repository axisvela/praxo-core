module praxo_openai
  use iso_fortran_env, only: int64, real64
  use praxo_types, only: sdk_error, request, response, string_value
  use praxo_interfaces, only: model
  use praxo_json, only: json_document, parse_json, json_get, json_children, &
    json_kind, json_text, json_real
  implicit none
  private
  public :: openai_transport, openai_compatible

  abstract interface
    function openai_transport(url, payload, api_key, error) result(body)
      import sdk_error
      character(*), intent(in) :: url, payload, api_key
      type(sdk_error), intent(out) :: error
      character(:), allocatable :: body
    end function
  end interface

  type, extends(model) :: openai_compatible
    character(:), allocatable :: base_url
    character(:), allocatable :: model_name
    character(:), allocatable :: api_key
    procedure(openai_transport), pointer, nopass :: transport => null()
  contains
    procedure :: generate => generate_openai
  end type
contains
  subroutine generate_openai(self, req, res, error)
    class(openai_compatible), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: payload, body
    if (.not. allocated(self%base_url) .or. len_trim(self%base_url) == 0) then
      error%code = 'PROVIDER_HTTP'
      return
    end if
    if (.not. associated(self%transport)) then
      error%code = 'PROVIDER_HTTP'
      return
    end if
    payload = build_payload(self, req)
    body = self%transport(endpoint(self%base_url), payload, &
      string_value(self%api_key), error)
    if (error%failed()) return
    call map_response(body, res, error)
  end subroutine

  function build_payload(self, req) result(payload)
    class(openai_compatible), intent(in) :: self
    type(request), intent(in) :: req
    character(:), allocatable :: payload
    integer :: i, j
    payload = '{"model":'//quote(string_value(self%model_name))//',"messages":['
    if (allocated(req%messages)) then
      do i = 1, size(req%messages)
        if (i > 1) payload = payload//','
        payload = payload//'{"role":'// &
          quote(string_value(req%messages(i)%role))//',"content":'// &
          quote(string_value(req%messages(i)%content))
        if (string_value(req%messages(i)%role) == 'assistant' .and. &
            allocated(req%messages(i)%tool_calls)) then
          if (size(req%messages(i)%tool_calls) > 0) then
            payload = payload//',"tool_calls":['
            do j = 1, size(req%messages(i)%tool_calls)
              if (j > 1) payload = payload//','
              payload = payload//'{"id":'// &
                quote(string_value(req%messages(i)%tool_calls(j)%id))// &
                ',"type":"function","function":{"name":'// &
                quote(string_value(req%messages(i)%tool_calls(j)%name))// &
                ',"arguments":'// &
                quote(string_value(req%messages(i)%tool_calls(j)%arguments))// &
                '}}'
            end do
            payload = payload//']'
          end if
        end if
        if (string_value(req%messages(i)%role) == 'tool' .and. &
            allocated(req%messages(i)%tool_call_id)) then
          if (len_trim(req%messages(i)%tool_call_id) > 0) then
            payload = payload//',"tool_call_id":'// &
              quote(req%messages(i)%tool_call_id)
          end if
        end if
        payload = payload//'}'
      end do
    end if
    payload = payload//']'
    if (allocated(req%tools)) then
      if (size(req%tools) > 0) then
        payload = payload//',"tools":['
        do i = 1, size(req%tools)
          if (i > 1) payload = payload//','
          payload = payload//'{"type":"function","function":{"name":'// &
            quote(string_value(req%tools(i)%name))//',"description":'// &
            quote(string_value(req%tools(i)%description))// &
            ',"parameters":{"type":"object"}}}'
        end do
        payload = payload//']'
      end if
    end if
    payload = payload//'}'
  end function

  subroutine map_response(body, res, error)
    character(*), intent(in) :: body
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    type(json_document) :: data, argument_document
    type(sdk_error) :: argument_error
    integer, allocatable :: children(:), calls(:)
    integer :: choices, choice, message, node, calls_node, usage_node, i
    character(:), allocatable :: text
    logical :: ok
    real(real64) :: value
    call parse_json(body, data, error)
    if (error%failed()) return
    choices = json_get(data, 1, 'choices')
    if (json_kind(data, choices) /= 'A') then
      error%code = 'PROVIDER_JSON'
      return
    end if
    children = json_children(data, choices)
    if (size(children) < 1) then
      error%code = 'PROVIDER_JSON'
      return
    end if
    choice = children(1)
    message = json_get(data, choice, 'message')
    if (json_kind(data, message) /= 'O') then
      error%code = 'PROVIDER_JSON'
      return
    end if
    res%message%role = 'assistant'
    res%message%content = ''
    node = json_get(data, message, 'content')
    if (json_kind(data, node) == 'S') res%message%content = json_text(data, node)
    calls_node = json_get(data, message, 'tool_calls')
    if (json_kind(data, calls_node) == 'A') then
      calls = json_children(data, calls_node)
      allocate(res%message%tool_calls(size(calls)))
      do i = 1, size(calls)
        res%message%tool_calls(i)%id = &
          json_text(data, json_get(data, calls(i), 'id'))
        node = json_get(data, calls(i), 'function')
        res%message%tool_calls(i)%name = &
          json_text(data, json_get(data, node, 'name'))
        text = json_text(data, json_get(data, node, 'arguments'))
        if (len(text) == 0) then
          res%message%tool_calls(i)%arguments = '{}'
        else
          call parse_json(text, argument_document, argument_error)
          if (argument_error%failed() .or. &
              json_kind(argument_document, 1) /= 'O') then
            error%code = 'PROVIDER_JSON'
            return
          end if
          res%message%tool_calls(i)%arguments = text
        end if
      end do
    end if
    usage_node = json_get(data, 1, 'usage')
    if (json_kind(data, usage_node) == 'O') then
      value = json_real(data, json_get(data, usage_node, 'prompt_tokens'), ok)
      if (ok) res%usage%input_tokens = int(value, int64)
      value = json_real(data, json_get(data, usage_node, 'completion_tokens'), ok)
      if (ok) res%usage%output_tokens = int(value, int64)
    end if
  end subroutine

  function endpoint(base) result(url)
    character(*), intent(in) :: base
    character(:), allocatable :: url
    url = trim(base)
    do while (len(url) > 0)
      if (url(len(url):len(url)) /= '/') exit
      url = url(:len(url) - 1)
    end do
    if (len(url) >= 17) then
      if (url(len(url) - 16:len(url)) == '/chat/completions') return
    end if
    url = url//'/chat/completions'
  end function

  function quote(text) result(output)
    character(*), intent(in) :: text
    character(:), allocatable :: output
    character(6) :: escape
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
end module
