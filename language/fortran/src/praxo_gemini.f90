module praxo_gemini
  use iso_fortran_env, only: int64, real64
  use praxo_types, only: sdk_error, request, response, string_value, tool_call, message
  use praxo_interfaces, only: model
  use praxo_json, only: json_document, parse_json, json_get, json_children, &
    json_kind, json_text, json_real
  implicit none
  private
  public :: gemini_transport, gemini_compatible

  abstract interface
    function gemini_transport(url, payload, api_key, error) result(body)
      import sdk_error
      character(*), intent(in) :: url, payload, api_key
      type(sdk_error), intent(out) :: error
      character(:), allocatable :: body
    end function
  end interface

  type, extends(model) :: gemini_compatible
    character(:), allocatable :: base_url
    character(:), allocatable :: model_name
    character(:), allocatable :: api_key
    integer :: max_output_tokens = 0
    procedure(gemini_transport), pointer, nopass :: transport => null()
  contains
    procedure :: generate => generate_gemini
  end type
contains
  subroutine generate_gemini(self, req, res, error)
    class(gemini_compatible), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: payload, body
    if (.not. allocated(self%api_key) .or. len_trim(self%api_key) == 0) then
      error%code = 'MODEL_CONFIG'
      return
    end if
    if (.not. allocated(self%model_name) .or. len_trim(self%model_name) == 0) then
      error%code = 'MODEL_CONFIG'
      return
    end if
    if (.not. associated(self%transport)) then
      error%code = 'PROVIDER_HTTP'
      return
    end if
    payload = build_payload(self, req)
    body = self%transport(endpoint(self%base_url, self%model_name), &
      payload, self%api_key, error)
    if (error%failed()) return
    call map_response(body, res, error)
  end subroutine

  function build_payload(self, req) result(payload)
    class(gemini_compatible), intent(in) :: self
    type(request), intent(in) :: req
    character(:), allocatable :: payload, system, role
    integer :: i
    logical :: pending
    system = ''
    payload = '{"contents":['
    pending = .false.
    if (allocated(req%messages)) then
      do i = 1, size(req%messages)
        select case (string_value(req%messages(i)%role))
        case ('system')
          if (len_trim(string_value(req%messages(i)%content)) > 0) then
            if (len(system) > 0) system = system//','
            system = system//'{"text":'// &
              quote(string_value(req%messages(i)%content))//'}'
          end if
        case ('tool')
          if (pending) payload = payload//','
          payload = payload//'{"role":"user","parts":[{"functionResponse":{'// &
            '"name":'//quote(string_value(req%messages(i)%tool_call_id))// &
            ',"response":{"result":'//quote(string_value(req%messages(i)%content))//'}}}]}'
          pending = .true.
        case default
          if (pending) payload = payload//','
          if (string_value(req%messages(i)%role) == 'assistant') then
            role = '"model"'
          else
            role = '"user"'
          end if
          payload = payload//'{"role":'//role// &
            ',"parts":'//message_parts(req%messages(i))//'}'
          pending = .true.
        end select
      end do
    end if
    payload = payload//']'
    if (len(system) > 0) payload = payload//',"system_instruction":{"parts":['//system//']}'
    if (allocated(req%tools)) then
      if (size(req%tools) > 0) then
        payload = payload//',"tools":[{"functionDeclarations":['
        do i = 1, size(req%tools)
          if (i > 1) payload = payload//','
          payload = payload//'{"name":'//quote(string_value(req%tools(i)%name))// &
            ',"description":'//quote(string_value(req%tools(i)%description))// &
            ',"parameters":{"type":"object"}}'
        end do
        payload = payload//']}],"toolConfig":{"functionCallingConfig":{"mode":"AUTO"}}'
      end if
    end if
    if (self%max_output_tokens > 0) then
      payload = payload//',"generationConfig":{"maxOutputTokens":'// &
        integer_text(self%max_output_tokens)//'}'
    end if
    payload = payload//'}'
  end function

  function message_parts(item) result(parts)
    type(message), intent(in) :: item
    character(:), allocatable :: parts
    integer :: j
    parts = '['
    if (len_trim(string_value(item%content)) > 0) then
      parts = parts//'{"text":'//quote(string_value(item%content))//'}'
    end if
    if (allocated(item%tool_calls)) then
      do j = 1, size(item%tool_calls)
        if (len(parts) > 1) parts = parts//','
        parts = parts//'{"functionCall":{"name":'// &
          quote(string_value(item%tool_calls(j)%name))//',"args":'// &
          string_value(item%tool_calls(j)%arguments)//'}}'
      end do
    end if
    parts = parts//']'
  end function

  subroutine map_response(body, res, error)
    character(*), intent(in) :: body
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    type(json_document) :: data
    integer, allocatable :: candidates(:), parts(:)
    integer :: candidates_node, content, candidate, part, usage, i
    character(:), allocatable :: text
    real(real64) :: value
    logical :: ok
    call parse_json(body, data, error)
    if (error%failed()) return
    candidates_node = json_get(data, 1, 'candidates')
    if (json_kind(data, candidates_node) /= 'A') then
      error%code = 'PROVIDER_HTTP'
      return
    end if
    candidates = json_children(data, candidates_node)
    if (size(candidates) < 1) then
      error%code = 'PROVIDER_HTTP'
      return
    end if
    candidate = candidates(1)
    content = json_get(data, candidate, 'content')
    parts = json_children(data, json_get(data, content, 'parts'))
    res%message%role = 'assistant'
    res%message%content = ''
    allocate(res%message%tool_calls(0))
    do i = 1, size(parts)
      part = parts(i)
      text = json_text(data, json_get(data, part, 'text'))
      if (len(text) > 0) res%message%content = &
        string_value(res%message%content)//text
      if (json_kind(data, json_get(data, part, 'functionCall')) == 'O') then
        call append_call(res%message%tool_calls, &
          json_text(data, json_get(data, json_get(data, part, 'functionCall'), 'name')), &
          node_json(data, json_get(data, json_get(data, part, 'functionCall'), 'args')))
      end if
    end do
    usage = json_get(data, 1, 'usageMetadata')
    if (json_kind(data, usage) == 'O') then
      value = json_real(data, json_get(data, usage, 'promptTokenCount'), ok)
      if (ok) res%usage%input_tokens = int(value, int64)
      value = json_real(data, json_get(data, usage, 'candidatesTokenCount'), ok)
      if (ok) res%usage%output_tokens = int(value, int64)
    end if
  end subroutine

  subroutine children_of(doc, parent, children)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: parent
    integer, allocatable, intent(out) :: children(:)
    children = json_children(doc, parent)
  end subroutine

  subroutine append_call(calls, name, arguments)
    type(tool_call), allocatable, intent(inout) :: calls(:)
    character(*), intent(in) :: name, arguments
    type(tool_call), allocatable :: temp(:)
    integer :: n
    n = size(calls)
    allocate(temp(n + 1))
    if (n > 0) temp(1:n) = calls
    temp(n + 1)%id = 'call-'//integer_text(n + 1)
    temp(n + 1)%name = name
    temp(n + 1)%arguments = arguments
    call move_alloc(temp, calls)
  end subroutine

  recursive function node_json(doc, node) result(output)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: node
    character(:), allocatable :: output
    integer, allocatable :: children(:)
    integer :: i
    select case (json_kind(doc, node))
    case ('O')
      output = '{'
      children = json_children(doc, node)
      do i = 1, size(children)
        if (i > 1) output = output//','
        output = output//quote(doc%nodes(children(i))%name)//':'// &
          node_json(doc, children(i))
      end do
      output = output//'}'
    case ('A')
      output = '['
      children = json_children(doc, node)
      do i = 1, size(children)
        if (i > 1) output = output//','
        output = output//node_json(doc, children(i))
      end do
      output = output//']'
    case ('S')
      output = quote(json_text(doc, node))
    case default
      output = doc%nodes(node)%text
    end select
  end function

  function endpoint(base, model_name) result(url)
    character(*), intent(in) :: base, model_name
    character(:), allocatable :: url
    url = trim(base)
    do while (len(url) > 0)
      if (url(len(url):len(url)) /= '/') exit
      url = url(:len(url) - 1)
    end do
    url = url//'/v1beta/models/'//trim(model_name)//':generateContent'
  end function

  function integer_text(value) result(text)
    integer, intent(in) :: value
    character(:), allocatable :: text
    character(32) :: buffer
    write(buffer, '(i0)') value
    text = trim(buffer)
  end function

  function quote(text) result(output)
    character(*), intent(in) :: text
    character(:), allocatable :: output
    integer :: i, code
    output = '"'
    do i = 1, len(text)
      code = iachar(text(i:i))
      select case (code)
      case (34)
        output = output//'\"'
      case (92)
        output = output//'\\'
      case (10)
        output = output//'\n'
      case (13)
        output = output//'\r'
      case (9)
        output = output//'\t'
      case default
        output = output//text(i:i)
      end select
    end do
    output = output//'"'
  end function
end module
