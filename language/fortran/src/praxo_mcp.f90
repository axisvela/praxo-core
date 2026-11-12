module praxo_mcp
  use praxo_types, only: sdk_error, same_string
  use praxo_json, only: json_document, parse_json, encode_json, json_get, &
    json_children, json_kind, json_text
  implicit none
  private
  public :: mcp_transport, mcp_client, mcp_client_new

  abstract interface
    subroutine mcp_transport(method, params, result, error)
      import sdk_error
      character(*), intent(in) :: method, params
      character(:), allocatable, intent(out) :: result
      type(sdk_error), intent(out) :: error
    end subroutine
  end interface

  type :: mcp_client
    character(:), allocatable :: client_version
    character(:), allocatable :: protocol_version
    character(:), allocatable :: server_info
    character(:), allocatable :: error_code
    character(:), allocatable :: error_message
    procedure(mcp_transport), pointer, nopass :: transport => null()
    logical :: closed = .false.
  contains
    procedure :: initialize => initialize_mcp
    procedure :: list_tools => list_tools_mcp
    procedure :: call_tool => call_tool_mcp
    procedure :: close => close_mcp
    procedure :: failed => failed_mcp
  end type
contains
  function mcp_client_new(transport, client_version, protocol_version) result(client)
    procedure(mcp_transport) :: transport
    character(*), intent(in), optional :: client_version, protocol_version
    type(mcp_client) :: client
    client%transport => transport
    if (present(client_version)) then
      client%client_version = client_version
    else
      client%client_version = '0.8.0'
    end if
    if (present(protocol_version)) then
      client%protocol_version = protocol_version
    else
      client%protocol_version = '2024-11-05'
    end if
  end function

  subroutine initialize_mcp(self, error)
    class(mcp_client), intent(inout) :: self
    type(sdk_error), intent(out) :: error
    type(json_document) :: document
    character(:), allocatable :: params, result, version, info
    integer :: node
    self%error_code = ''
    self%error_message = ''
    if (.not. associated(self%transport)) then
      call set_error(self, 'MCP_TRANSPORT', 'mcp: transport is required')
      error%code = self%error_code
      return
    end if
    params = '{"protocolVersion":'//quote(self%protocol_version)// &
      ',"capabilities":{},"clientInfo":{"name":"praxo-core","version":'// &
      quote(self%client_version)//'}}'
    call self%transport('initialize', params, result, error)
    if (error%failed()) then
      call set_error(self, error%code, 'mcp: initialize transport failed')
      error%code = self%error_code
      return
    end if
    call parse_json(result, document, error)
    if (error%failed()) then
      call set_error(self, 'MCP_PROTOCOL', 'mcp: initialize result must be an object')
      error%code = self%error_code
      return
    end if
    if (json_kind(document, 1) /= 'O') then
      call set_error(self, 'MCP_PROTOCOL', 'mcp: initialize result must be an object')
      error%code = self%error_code
      return
    end if
    node = json_get(document, 1, 'protocolVersion')
    if (json_kind(document, node) /= 'S') then
      call set_error(self, 'MCP_HANDSHAKE', &
        'mcp: initialize returned no protocol version')
      error%code = self%error_code
      return
    end if
    version = json_text(document, node)
    if (len_trim(version) == 0) then
      call set_error(self, 'MCP_HANDSHAKE', &
        'mcp: initialize returned no protocol version')
      error%code = self%error_code
      return
    end if
    self%protocol_version = version
    node = json_get(document, 1, 'serverInfo')
    if (json_kind(document, node) == 'O') then
      info = encode_json(document, node, error)
      if (error%failed()) then
        call set_error(self, 'MCP_PROTOCOL', 'mcp: invalid serverInfo')
        error%code = self%error_code
        return
      end if
      self%server_info = info
    else
      self%server_info = '{}'
    end if
  end subroutine

  function list_tools_mcp(self, error) result(tools)
    class(mcp_client), intent(inout) :: self
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: tools, params, result, cursor, item
    type(json_document) :: document
    integer, allocatable :: children(:)
    character(len=1024), allocatable :: names(:), cursors(:)
    integer :: names_count, cursors_count, tools_node, next_node, i, name_node
    logical :: first
    tools = '['
    first = .true.
    names_count = 0
    cursors_count = 0
    cursor = ''
    self%error_code = ''
    self%error_message = ''
    if (.not. associated(self%transport)) then
      call set_error(self, 'MCP_TRANSPORT', 'mcp: transport is required')
      error%code = self%error_code
      tools = ''
      return
    end if
    do
      if (len_trim(cursor) == 0) then
        params = '{}'
      else
        params = '{"cursor":'//quote(cursor)//'}'
      end if
      call self%transport('tools/list', params, result, error)
      if (error%failed()) then
        call set_error(self, error%code, 'mcp: tools/list transport failed')
        error%code = self%error_code
        tools = ''
        return
      end if
      call parse_json(result, document, error)
      if (error%failed() .or. json_kind(document, 1) /= 'O') then
        call set_error(self, 'MCP_PROTOCOL', 'mcp: tools/list result must be an object')
        error%code = self%error_code
        tools = ''
        return
      end if
      tools_node = json_get(document, 1, 'tools')
      if (json_kind(document, tools_node) /= 'A') then
        call set_error(self, 'MCP_PROTOCOL', 'mcp: tools/list tools must be an array')
        error%code = self%error_code
        tools = ''
        return
      end if
      children = json_children(document, tools_node)
      do i = 1, size(children)
        if (json_kind(document, children(i)) /= 'O') then
          call set_error(self, 'MCP_PROTOCOL', 'mcp: tool definition must be an object')
          error%code = self%error_code
          tools = ''
          return
        end if
        name_node = json_get(document, children(i), 'name')
        if (json_kind(document, name_node) /= 'S') then
          call set_error(self, 'MCP_PROTOCOL', 'mcp: tool name is required')
          error%code = self%error_code
          tools = ''
          return
        end if
        item = json_text(document, name_node)
        if (len_trim(item) == 0) then
          call set_error(self, 'MCP_PROTOCOL', 'mcp: tool name is required')
          error%code = self%error_code
          tools = ''
          return
        end if
        if (contains_string(names, names_count, item)) then
          call set_error(self, 'MCP_DUPLICATE_TOOL', 'mcp: duplicate tool '//item)
          error%code = self%error_code
          tools = ''
          return
        end if
        call append_fixed(names, names_count, item)
        item = encode_json(document, children(i), error)
        if (error%failed()) then
          call set_error(self, 'MCP_PROTOCOL', 'mcp: invalid tool definition')
          error%code = self%error_code
          tools = ''
          return
        end if
        if (.not. first) tools = tools//','
        tools = tools//item
        first = .false.
      end do
      next_node = json_get(document, 1, 'nextCursor')
      if (json_kind(document, next_node) == 'Z') exit
      if (json_kind(document, next_node) == ' ') exit
      if (json_kind(document, next_node) /= 'S') then
        call set_error(self, 'MCP_PROTOCOL', 'mcp: nextCursor must be a string')
        error%code = self%error_code
        tools = ''
        return
      end if
      cursor = json_text(document, next_node)
      if (len_trim(cursor) == 0) exit
      if (contains_string(cursors, cursors_count, cursor)) then
        call set_error(self, 'MCP_PAGINATION', &
          'mcp: repeated tool pagination cursor')
        error%code = self%error_code
        tools = ''
        return
      end if
      call append_fixed(cursors, cursors_count, cursor)
    end do
    tools = tools//']'
  end function

  function call_tool_mcp(self, name, arguments, error) result(value)
    class(mcp_client), intent(inout) :: self
    character(*), intent(in) :: name
    character(*), intent(in), optional :: arguments
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: value, params, result, single, array, item
    type(json_document) :: document
    integer, allocatable :: children(:)
    integer :: node, text_node, kind_node, i, count
    self%error_code = ''
    self%error_message = ''
    value = ''
    if (.not. associated(self%transport)) then
      call set_error(self, 'MCP_TRANSPORT', 'mcp: transport is required')
      error%code = self%error_code
      return
    end if
    if (len_trim(name) == 0) then
      call set_error(self, 'MCP_PROTOCOL', 'mcp: tool name is required')
      error%code = self%error_code
      return
    end if
    if (present(arguments)) then
      params = '{"name":'//quote(name)//',"arguments":'//arguments//'}'
    else
      params = '{"name":'//quote(name)//',"arguments":{}}'
    end if
    call self%transport('tools/call', params, result, error)
    if (error%failed()) then
      call set_error(self, error%code, 'mcp: tools/call transport failed')
      error%code = self%error_code
      return
    end if
    call parse_json(result, document, error)
    if (error%failed() .or. json_kind(document, 1) /= 'O') then
      call set_error(self, 'MCP_PROTOCOL', 'mcp: tools/call result must be an object')
      error%code = self%error_code
      return
    end if
    node = json_get(document, 1, 'isError')
    if (json_kind(document, node) == 'T') then
      call set_error(self, 'MCP_TOOL_ERROR', 'mcp: tool '//name//' failed')
      error%code = self%error_code
      return
    end if
    node = json_get(document, 1, 'structuredContent')
    if (json_kind(document, node) /= ' ') then
      value = encode_json(document, node, error)
      if (error%failed()) then
        call set_error(self, 'MCP_PROTOCOL', 'mcp: invalid structured content')
        error%code = self%error_code
        value = ''
      end if
      return
    end if
    node = json_get(document, 1, 'content')
    count = 0
    array = '['
    single = ''
    if (json_kind(document, node) == 'A') then
      children = json_children(document, node)
      do i = 1, size(children)
        if (json_kind(document, children(i)) /= 'O') cycle
        kind_node = json_get(document, children(i), 'type')
        text_node = json_get(document, children(i), 'text')
        if (json_kind(document, kind_node) /= 'S') cycle
        if (.not. same_string(json_text(document, kind_node), 'text')) cycle
        if (json_kind(document, text_node) /= 'S') cycle
        item = encode_json(document, text_node, error)
        if (error%failed()) then
          call set_error(self, 'MCP_PROTOCOL', 'mcp: invalid text content')
          error%code = self%error_code
          value = ''
          return
        end if
        count = count + 1
        if (count == 1) then
          single = item
        else if (count == 2) then
          array = array//single//','//item
        else
          array = array//','//item
        end if
      end do
    end if
    select case (count)
    case (0)
      value = 'null'
    case (1)
      value = single
    case default
      value = array//']'
    end select
  end function

  subroutine close_mcp(self)
    class(mcp_client), intent(inout) :: self
    self%closed = .true.
  end subroutine

  logical function failed_mcp(self) result(failed)
    class(mcp_client), intent(in) :: self
    failed = len_trim(self%error_code) > 0
  end function

  subroutine set_error(self, code, message)
    class(mcp_client), intent(inout) :: self
    character(*), intent(in) :: code, message
    self%error_code = code
    self%error_message = message
  end subroutine

  subroutine append_fixed(values, count, value)
    character(len=*), allocatable, intent(inout) :: values(:)
    integer, intent(inout) :: count
    character(*), intent(in) :: value
    character(len=1024), allocatable :: grown(:)
    allocate(grown(count + 1))
    if (count > 0) grown(:count) = values
    grown(count + 1) = value
    call move_alloc(grown, values)
    count = count + 1
  end subroutine

  logical function contains_string(values, count, value) result(found)
    character(len=*), allocatable, intent(in) :: values(:)
    integer, intent(in) :: count
    character(*), intent(in) :: value
    integer :: i
    found = .false.
    do i = 1, count
      if (.not. same_string(trim(values(i)), value)) cycle
      found = .true.
      return
    end do
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
end module
