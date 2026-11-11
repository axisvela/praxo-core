module provider_tests
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_anthropic
  use praxo_gemini
  implicit none
contains
  function fake_anthropic(url, payload, api_key, version, error) result(body)
    character(*), intent(in) :: url, payload, api_key, version
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (index(url, '/v1/messages') == 0) error%code = 'TEST_URL'
    if (api_key /= 'ak') error%code = 'TEST_KEY'
    if (version /= '2023-06-01') error%code = 'TEST_VERSION'
    if (index(payload, '"system":"be brief"') == 0) error%code = 'TEST_SYSTEM'
    if (index(payload, '"input_schema"') == 0) error%code = 'TEST_TOOLS'
    body = '{"content":[{"type":"text","text":"hello"},'// &
      '{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],'// &
      '"stop_reason":"end_turn",'// &
      '"usage":{"input_tokens":3,"output_tokens":4,"cache_read_input_tokens":2}}'
  end function

  function fake_gemini(url, payload, api_key, error) result(body)
    character(*), intent(in) :: url, payload, api_key
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (index(url, ':generateContent') == 0) error%code = 'TEST_URL'
    if (api_key /= 'gk') error%code = 'TEST_KEY'
    if (index(payload, '"system_instruction"') == 0) error%code = 'TEST_SYSTEM'
    if (index(payload, '"functionDeclarations"') == 0) error%code = 'TEST_TOOLS'
    body = '{"candidates":[{"content":{"parts":['// &
      '{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},'// &
      '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,'// &
      '"candidatesTokenCount":4}}'
  end function

  subroutine check(condition, message)
    logical, intent(in) :: condition
    character(*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'FAIL: '//message
      error stop 1
    end if
  end subroutine

  subroutine run
    type(anthropic_compatible) :: claude
    type(gemini_compatible) :: gemini
    type(request) :: req
    type(response) :: res
    type(sdk_error) :: error
    allocate(req%messages(2))
    req%messages(1) = text_message('system', 'be brief')
    req%messages(2) = text_message('user', 'hi')
    allocate(req%tools(1))
    req%tools(1)%name = 'echo'
    req%tools(1)%description = 'Echo'

    claude%base_url = 'https://example.test'
    claude%model_name = 'claude-test'
    claude%api_key = 'ak'
    claude%transport => fake_anthropic
    call claude%generate(req, res, error)
    call check(.not. error%failed(), 'anthropic error')
    call check(res%message%content == 'hello', 'anthropic content')
    call check(res%message%tool_calls(1)%id == 'tool-1', 'anthropic call id')
    call check(res%message%tool_calls(1)%arguments == '{"text":"hi"}', 'anthropic arguments')
    call check(res%usage%input_tokens == 3 .and. res%usage%output_tokens == 4, 'anthropic usage')

    gemini%base_url = 'https://example.test'
    gemini%model_name = 'gemini-test'
    gemini%api_key = 'gk'
    gemini%transport => fake_gemini
    call gemini%generate(req, res, error)
    call check(.not. error%failed(), 'gemini error')
    call check(res%message%content == 'hello', 'gemini content')
    call check(res%message%tool_calls(1)%name == 'echo', 'gemini call name')
    call check(res%message%tool_calls(1)%arguments == '{"text":"hi"}', 'gemini arguments')
    call check(res%usage%input_tokens == 3 .and. res%usage%output_tokens == 4, 'gemini usage')
    write(*, '(a)') 'fortran provider tests passed'
  end subroutine
end module

program providers
  use provider_tests
  call run
end program
