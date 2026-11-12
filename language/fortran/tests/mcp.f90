module fake_mcp
  use praxo_types, only: sdk_error, same_string
  implicit none
  integer :: mode = 1
contains
  subroutine transport(method, params, result, error)
    character(*), intent(in) :: method, params
    character(:), allocatable, intent(out) :: result
    type(sdk_error), intent(out) :: error
    error%code = ''
    if (same_string(method, 'initialize')) then
      result = '{"protocolVersion":"2024-11-05","serverInfo":{"name":"fake"}}'
    else if (same_string(method, 'tools/list')) then
      if (mode == 2) then
        result = '{"tools":[{"name":"echo"},{"name":"echo"}]}'
      else if (mode == 3) then
        result = '{"tools":[],"nextCursor":"c1"}'
      else if (index(params, '"cursor"') > 0) then
        result = '{"tools":[{"name":"two"}]}'
      else
        result = '{"tools":[{"name":"echo","description":"Echo"}],"nextCursor":"c1"}'
      end if
    else if (mode == 4) then
      result = '{"isError":true}'
    else if (mode == 5) then
      result = '{"structuredContent":{"ok":true}}'
    else
      result = '{"content":[{"type":"text","text":"ok"}]}'
    end if
  end subroutine
end module

program mcp_tests
  use praxo_mcp
  use praxo_types, only: sdk_error
  use fake_mcp
  implicit none
  type(mcp_client) :: client
  type(sdk_error) :: error
  character(:), allocatable :: tools, value

  client = mcp_client_new(transport)
  call client%initialize(error)
  if (error%failed()) error stop 1
  if (.not. same_string(client%protocol_version, '2024-11-05')) error stop 2

  tools = client%list_tools(error)
  if (error%failed()) error stop 3
  if (.not. same_string(tools, &
      '[{"name":"echo","description":"Echo"},{"name":"two"}]')) error stop 4

  value = client%call_tool('echo', '{}', error)
  if (error%failed()) error stop 5
  if (.not. same_string(value, '"ok"')) error stop 6

  mode = 5
  value = client%call_tool('echo', error=error)
  if (error%failed()) error stop 7
  if (.not. same_string(value, '{"ok":true}')) error stop 8

  mode = 2
  tools = client%list_tools(error)
  if (.not. same_string(error%code, 'MCP_DUPLICATE_TOOL')) error stop 9

  mode = 3
  tools = client%list_tools(error)
  if (.not. same_string(error%code, 'MCP_PAGINATION')) error stop 10

  mode = 4
  value = client%call_tool('echo', '{}', error)
  if (.not. same_string(error%code, 'MCP_TOOL_ERROR')) error stop 11

  call client%close()
  if (.not. client%closed) error stop 12
end program
