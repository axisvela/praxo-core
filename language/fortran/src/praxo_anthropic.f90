module praxo_anthropic
  use iso_fortran_env, only: int64, real64
  use praxo_types, only: sdk_error, request, response, string_value, tool_call, message
  use praxo_interfaces, only: model, delta_interface
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
    procedure :: generate_stream => generate_stream_anthropic
  end type

  type :: anthropic_stream_call
    character(:), allocatable :: id, name, arguments
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

  subroutine generate_stream_anthropic(self, req, on_delta, ctx, res, error)
    class(anthropic_compatible), intent(inout) :: self
    type(request), intent(in) :: req
    procedure(delta_interface) :: on_delta
    class(*), pointer, intent(in) :: ctx
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
    payload = payload(:len(payload) - 1)//',"stream":true}'
    body = self%transport(endpoint(self%base_url), payload, &
      self%api_key, version, error)
    if (error%failed()) return
    call map_stream_response(body, on_delta, ctx, res, error)
  end subroutine

  subroutine map_stream_response(body, on_delta, ctx, res, error)
    character(*), intent(in) :: body
    procedure(delta_interface) :: on_delta
    class(*), pointer, intent(in) :: ctx
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    type(json_document) :: doc, argument_document
    type(sdk_error) :: delta_error, argument_error
    type(anthropic_stream_call) :: calls(8)
    integer :: start, finish, newline, i, node, block, delta
    integer :: slot, call_count, chosen
    character(:), allocatable :: line, chunk, kind, piece, reason, raw_arguments
    real(real64) :: value
    logical :: done, ok
    res%message%role = 'assistant'
    res%message%content = ''
    res%usage%input_tokens = 0
    res%usage%output_tokens = 0
    call_count = 0
    reason = ''
    done = .false.
    do i = 1, 8
      calls(i)%id = ''
      calls(i)%name = ''
      calls(i)%arguments = ''
    end do
    start = 1
    do while (start <= len(body) .and. .not. error%failed() .and. .not. done)
      newline = index(body(start:), achar(10))
      if (newline == 0) then
        finish = len(body) + 1
      else
        finish = start + newline - 1
      end if
      if (finish > start) then
        line = body(start:finish - 1)
      else
        line = ''
      end if
      line = trim(line)
      if (len_trim(line) > 1) then
        if (line(len_trim(line):len_trim(line)) == achar(13)) &
          line = line(:len_trim(line) - 1)
      end if
      if (len(line) >= 5 .and. line(1:5) == 'data:') then
        if (len(line) > 5) then
          chunk = trim(adjustl(line(6:)))
        else
          chunk = ''
        end if
        if (len_trim(chunk) > 0) then
          call parse_json(trim(chunk), doc, error)
          if (error%failed()) then
            error%code = 'MODEL_STREAM'
          else
            kind = json_text(doc, json_get(doc, 1, 'type'))
            select case (kind)
            case ('message_start')
              node = json_get(doc, 1, 'message')
              block = json_get(doc, node, 'usage')
              value = json_real(doc, json_get(doc, block, 'input_tokens'), ok)
              if (ok) res%usage%input_tokens = int(value, int64)
            case ('content_block_start')
              value = json_real(doc, json_get(doc, 1, 'index'), ok)
              slot = 1
              if (ok) slot = int(value) + 1
              if (slot >= 1 .and. slot <= 8) then
                block = json_get(doc, 1, 'content_block')
                if (json_text(doc, json_get(doc, block, 'type')) == 'tool_use') then
                  calls(slot)%id = json_text(doc, json_get(doc, block, 'id'))
                  calls(slot)%name = json_text(doc, json_get(doc, block, 'name'))
                  if (slot > call_count) call_count = slot
                end if
              end if
            case ('content_block_delta')
              value = json_real(doc, json_get(doc, 1, 'index'), ok)
              slot = 1
              if (ok) slot = int(value) + 1
              delta = json_get(doc, 1, 'delta')
              kind = json_text(doc, json_get(doc, delta, 'type'))
              if (kind == 'text_delta') then
                piece = json_text(doc, json_get(doc, delta, 'text'))
                if (len(piece) > 0 .and. len(res%message%content) < 32768) then
                  res%message%content = res%message%content//piece
                  delta_error%code = ''
                  call on_delta(ctx, piece, delta_error)
                  if (delta_error%failed()) error = delta_error
                end if
              else if (kind == 'input_json_delta') then
                if (slot >= 1 .and. slot <= 8) then
                  raw_arguments = json_text(doc, json_get(doc, delta, 'partial_json'))
                  if (len(calls(slot)%arguments) < 2048) then
                    calls(slot)%arguments = calls(slot)%arguments//raw_arguments
                  end if
                  if (slot > call_count) call_count = slot
                end if
              end if
            case ('message_delta')
              delta = json_get(doc, 1, 'delta')
              raw_arguments = json_text(doc, json_get(doc, delta, 'stop_reason'))
              if (len(raw_arguments) > 0) then
                reason = raw_arguments
                done = .true.
              end if
              node = json_get(doc, 1, 'usage')
              value = json_real(doc, json_get(doc, node, 'output_tokens'), ok)
              if (ok) res%usage%output_tokens = int(value, int64)
            case ('message_stop')
              done = .true.
            case ('error')
              error%code = 'MODEL_STREAM'
            end select
          end if
        end if
      end if
      if (newline == 0) exit
      start = finish + 1
    end do
    if (.not. error%failed() .and. .not. done) error%code = 'MODEL_STREAM'
    if (error%failed()) return
    chosen = 0
    do i = 1, call_count
      if (len_trim(calls(i)%name) > 0) chosen = chosen + 1
    end do
    if (chosen > 0) then
      allocate(res%message%tool_calls(chosen))
      chosen = 0
      do i = 1, call_count
        if (len_trim(calls(i)%name) == 0) cycle
        chosen = chosen + 1
        res%message%tool_calls(chosen)%id = calls(i)%id
        res%message%tool_calls(chosen)%name = calls(i)%name
        if (len_trim(calls(i)%arguments) == 0) then
          res%message%tool_calls(chosen)%arguments = '{}'
        else
          call parse_json(calls(i)%arguments, argument_document, argument_error)
          if (argument_error%failed() .or. &
              json_kind(argument_document, 1) /= 'O') then
            error%code = 'PROVIDER_JSON'
            return
          end if
          res%message%tool_calls(chosen)%arguments = calls(i)%arguments
        end if
      end do
    end if
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
