module praxo_anthropic
  use iso_fortran_env, only: int64, real64
  use praxo_types, only: sdk_error, request, response, string_value, tool_call, message
  use praxo_interfaces, only: model
  use praxo_json, only: json_document, parse_json, json_get, json_children, &
    json_kind, json_text, json_real
  implicit none
  private
  public :: anthropic_transport, anthropic_compatible

  abstract interface
    function anthropic_transport(url, payload, api_key, version, error) result(body)
      import sdk_error
      character(*), intent(in) :: url, payload, api_key, version
      type(sdk_error), intent(out) :: error
      character(:), allocatable :: body
    end function
  end interface

  type, extends(model) :: anthropic_compatible
    character(:), allocatable :: base_url
    character(:), allocatable :: model_name
    character(:), allocatable :: api_key
    character(:), allocatable :: version
    integer :: max_tokens = 1024
    procedure(anthropic_transport), pointer, nopass :: transport => null()
  contains
    procedure :: generate => generate_anthropic
  end type
contains
  subroutine generate_anthropic(self, req, res, error)
    class(anthropic_compatible), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: payload, body, version
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
    version = '2023-06-01'
    if (allocated(self%version)) then
      if (len_trim(self%version) > 0) version = self%version
    end if
    payload = build_payload(self, req)
    body = self%transport(endpoint(self%base_url), payload, &
      self%api_key, version, error)
    if (error%failed()) return
    call map_response(body, res, error)
  end subroutine

  function build_payload(self, req) result(payload)
    class(anthropic_compatible), intent(in) :: self
    type(request), intent(in) :: req
    character(:), allocatable :: payload, system
    character(:), allocatable :: content
    integer :: i
    logical :: pending
    system = ''
    payload = '{"model":'//quote(self%model_name)//',"max_tokens":'// &
      integer_text(self%max_tokens)//',"messages":['
    pending = .false.
    if (allocated(req%messages)) then
      do i = 1, size(req%messages)
        select case (string_value(req%messages(i)%role))
        case ('system')
          if (len_trim(string_value(req%messages(i)%content)) > 0) then
            if (len(system) > 0) system = system//'\n\n'
            system = system//string_value(req%messages(i)%content)
          end if
        case ('tool')
          if (pending) payload = payload//','
          payload = payload//'{"role":"user","content":[{"type":"tool_result",'// &
            '"tool_use_id":'//quote(string_value(req%messages(i)%tool_call_id))// &
            ',"content":'//quote(string_value(req%messages(i)%content))//'}]}'
          pending = .true.
        case default
          content = message_content(req%messages(i))
          if (len(content) > 2) then
            if (pending) payload = payload//','
            payload = payload//'{"role":'//quote(string_value(req%messages(i)%role))// &
              ',"content":'//content//'}'
            pending = .true.
          end if
        end select
      end do
    end if
    payload = payload//']'
    if (len(system) > 0) payload = payload//',"system":'//quote(system)
    if (allocated(req%tools)) then
      if (size(req%tools) > 0) then
        payload = payload//',"tools":['
        do i = 1, size(req%tools)
          if (i > 1) payload = payload//','
          payload = payload//'{"name":'//quote(string_value(req%tools(i)%name))// &
            ',"description":'//quote(string_value(req%tools(i)%description))// &
            ',"input_schema":{"type":"object"}}'
        end do
        payload = payload//']'
      end if
    end if
    payload = payload//'}'
  end function

  function message_content(item) result(content)
    type(message), intent(in) :: item
    character(:), allocatable :: content
    integer :: j
    content = '['
    if (len_trim(string_value(item%content)) > 0) then
      content = content//'{"type":"text","text":'// &
        quote(string_value(item%content))//'}'
    end if
    if (allocated(item%tool_calls)) then
      do j = 1, size(item%tool_calls)
        if (len(content) > 1) content = content//','
        content = content//'{"type":"tool_use","id":'// &
          quote(string_value(item%tool_calls(j)%id))//',"name":'// &
          quote(string_value(item%tool_calls(j)%name))//',"input":'// &
          string_value(item%tool_calls(j)%arguments)//'}'
      end do
    end if
    content = content//']'
  end function

  subroutine map_response(body, res, error)
    character(*), intent(in) :: body
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    type(json_document) :: data
    integer, allocatable :: blocks(:)
    integer :: content, block, usage, i
    character(:), allocatable :: text
    real(real64) :: value
    logical :: ok
    call parse_json(body, data, error)
    if (error%failed()) return
    content = json_get(data, 1, 'content')
    if (json_kind(data, content) /= 'A') then
      error%code = 'PROVIDER_JSON'
      return
    end if
    res%message%role = 'assistant'
    res%message%content = ''
    allocate(res%message%tool_calls(0))
    blocks = json_children(data, content)
    do i = 1, size(blocks)
      block = blocks(i)
      if (json_kind(data, json_get(data, block, 'type')) /= 'S') cycle
      text = json_text(data, json_get(data, block, 'type'))
      if (text == 'text') then
        text = json_text(data, json_get(data, block, 'text'))
        if (len(text) > 0) res%message%content = &
          string_value(res%message%content)//text
      else if (text == 'tool_use') then
        call append_call(res%message%tool_calls, &
          json_text(data, json_get(data, block, 'id')), &
          json_text(data, json_get(data, block, 'name')), &
          node_json(data, json_get(data, block, 'input')))
      end if
    end do
    usage = json_get(data, 1, 'usage')
    if (json_kind(data, usage) == 'O') then
      value = json_real(data, json_get(data, usage, 'input_tokens'), ok)
      if (ok) res%usage%input_tokens = int(value, int64)
      value = json_real(data, json_get(data, usage, 'output_tokens'), ok)
      if (ok) res%usage%output_tokens = int(value, int64)
    end if
  end subroutine

  subroutine append_call(calls, id, name, arguments)
    type(tool_call), allocatable, intent(inout) :: calls(:)
    character(*), intent(in) :: id, name, arguments
    type(tool_call), allocatable :: temp(:)
    integer :: n
    n = size(calls)
    allocate(temp(n + 1))
    if (n > 0) temp(1:n) = calls
    temp(n + 1)%id = id
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
    character :: kind
    allocate(children(0))
    kind = json_kind(doc, node)
    select case (kind)
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

  function endpoint(base) result(url)
    character(*), intent(in) :: base
    character(:), allocatable :: url
    url = trim(base)
    do while (len(url) > 0)
      if (url(len(url):len(url)) /= '/') exit
      url = url(:len(url) - 1)
    end do
    url = url//'/v1/messages'
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
