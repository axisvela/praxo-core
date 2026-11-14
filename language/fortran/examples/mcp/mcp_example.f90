module mcp_example_transport
  use praxo_types, only: sdk_error, same_string
  implicit none
contains
  subroutine transport(method, params, result, error)
    character(*), intent(in) :: method, params
    character(:), allocatable, intent(out) :: result
    type(sdk_error), intent(out) :: error
    error%code = ''
    if (same_string(method, 'initialize')) then
      result = '{"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}}'
    else if (same_string(method, 'tools/list')) then
      result = '{"tools":[{"name":"echo"},{"name":"add"}]}'
    else if (same_string(method, 'tools/call')) then
      result = '{"structuredContent":{"sum":5}}'
    else
      result = '{}'
    end if
  end subroutine
end module

program mcp_example
  use praxo_types, only: sdk_error, same_string
  use praxo_mcp
  use mcp_example_transport
  implicit none
  type(mcp_client) :: client
  type(sdk_error) :: error
  character(:), allocatable :: tools, value

  client = mcp_client_new(transport)
  call client%initialize(error)
  if (error%failed()) stop 1
  tools = client%list_tools(error)
  if (error%failed() .or. tools /= '[{"name":"echo"},{"name":"add"}]') stop 1
  value = client%call_tool('add', '{}', error)
  if (error%failed() .or. value /= '{"sum":5}') stop 1
  call client%close()
  print '(a)', 'Fortran MCP example passed'
end program
