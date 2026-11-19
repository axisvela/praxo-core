module provider_tests
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_anthropic
  use praxo_gemini
  use praxo_openai, only: openai_compatible
  implicit none
  character(:), allocatable :: streamed_delta
contains
  subroutine collect_delta(ctx, delta, error)
    class(*), pointer, intent(in) :: ctx
    character(*), intent(in) :: delta
    type(sdk_error), intent(inout) :: error
    if (associated(ctx)) error%code = ''
    streamed_delta = streamed_delta // delta
  end subroutine
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

  function fake_anthropic_stream(url, payload, api_key, version, error) result(body)
    character(*), intent(in) :: url, payload, api_key, version
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (index(url, '/v1/messages') == 0) error%code = 'TEST_URL'
    if (api_key /= 'ak') error%code = 'TEST_KEY'
    if (version /= '2023-06-01') error%code = 'TEST_VERSION'
    if (index(payload, '"stream":true') == 0) error%code = 'TEST_STREAM'
    body = 'data: {"type":"message_start","message":{"usage":'// &
      '{"input_tokens":4,"cache_read_input_tokens":1}}}'//achar(10)// &
      'data: {"type":"content_block_start","index":0,'// &
      '"content_block":{"type":"text","text":""}}'//achar(10)// &
      'data: {"type":"content_block_delta","index":0,'// &
      '"delta":{"type":"text_delta","text":"he"}}'//achar(10)// &
      'data: {"type":"content_block_delta","index":0,'// &
      '"delta":{"type":"text_delta","text":"llo"}}'//achar(10)// &
      'data: {"type":"content_block_start","index":1,'// &
      '"content_block":{"type":"tool_use","id":"call-1",'// &
      '"name":"echo","input":{}}}'//achar(10)// &
      'data: {"type":"content_block_delta","index":1,'// &
      '"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}'// &
      achar(10)// &
      'data: {"type":"content_block_delta","index":1,'// &
      '"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}'// &
      achar(10)// &
      'data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},'// &
      '"usage":{"output_tokens":2}}'//achar(10)// &
      'data: {"type":"message_stop"}'//achar(10)
  end function

  function fake_openai_stream(url, payload, api_key, error) result(body)
    character(*), intent(in) :: url, payload, api_key
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (index(url, '/chat/completions') == 0) error%code = 'TEST_URL'
    if (api_key /= 'sk') error%code = 'TEST_KEY'
    if (index(payload, '"stream":true') == 0) error%code = 'TEST_STREAM'
    body = 'data: {"choices":[{"delta":{"content":"he"}}]}'//achar(10)// &
      'data: {"choices":[{"delta":{"content":"llo"}}]}'//achar(10)// &
      'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1",'// &
      '"function":{"name":"ec","arguments":"{\"text\":"}}]}}]}'//achar(10)// &
      'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'// &
      '"function":{"name":"ho","arguments":"\"hi\"}"}}]}}],'// &
      '"usage":{"prompt_tokens":4,"completion_tokens":2}}'//achar(10)// &
      'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'//achar(10)// &
      'data: [DONE]'
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

  function fake_gemini_stream(url, payload, api_key, error) result(body)
    character(*), intent(in) :: url, payload, api_key
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: body
    if (index(url, ':streamGenerateContent?alt=sse') == 0) error%code = 'TEST_URL'
    if (api_key /= 'gk') error%code = 'TEST_KEY'
    if (index(payload, '"contents"') == 0) error%code = 'TEST_PAYLOAD'
    body = 'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}'// & 
      achar(10)// &
      'data: {"candidates":[{"content":{"parts":[{"text":"llo"},'// &
      '{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},'// &
      '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,'// &
      '"candidatesTokenCount":2}}'//achar(10)
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
    type(openai_compatible) :: openai
    class(*), pointer :: no_ctx => null()
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

    claude%transport => fake_anthropic_stream
    streamed_delta = ''
    call claude%generate_stream(req, collect_delta, no_ctx, res, error)
    call check(.not. error%failed(), 'anthropic stream error')
    call check(streamed_delta == 'hello', 'anthropic stream deltas')
    call check(res%message%content == 'hello', 'anthropic stream content')
    call check(res%message%tool_calls(1)%id == 'call-1', 'anthropic stream call id')
    call check(res%message%tool_calls(1)%name == 'echo', 'anthropic stream call name')
    call check(res%message%tool_calls(1)%arguments == '{"text":"hi"}', &
      'anthropic stream arguments')
    call check(res%usage%input_tokens == 4 .and. res%usage%output_tokens == 2, &
      'anthropic stream usage')

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

    openai%base_url = 'https://example.test'
    openai%model_name = 'test-model'
    openai%api_key = 'sk'
    openai%transport => fake_openai_stream
    streamed_delta = ''
    call openai%generate_stream(req, collect_delta, no_ctx, res, error)
    call check(.not. error%failed(), 'openai stream error')
    call check(streamed_delta == 'hello', 'openai stream deltas')
    call check(res%message%content == 'hello', 'openai stream content')
    call check(res%message%tool_calls(1)%id == 'call-1', 'openai stream call id')
    call check(res%message%tool_calls(1)%name == 'echo', 'openai stream call name')
    call check(res%message%tool_calls(1)%arguments == '{"text":"hi"}', &
      'openai stream arguments')
    call check(res%usage%input_tokens == 4 .and. res%usage%output_tokens == 2, &
      'openai stream usage')
    gemini%base_url = 'https://example.test'
    gemini%model_name = 'gemini-test'
    gemini%api_key = 'gk'
    gemini%transport => fake_gemini_stream
    streamed_delta = ''
    call gemini%generate_stream(req, collect_delta, no_ctx, res, error)
    call check(.not. error%failed(), 'gemini stream error')
    call check(streamed_delta == 'hello', 'gemini stream deltas')
    call check(res%message%content == 'hello', 'gemini stream content')
    call check(res%message%tool_calls(1)%name == 'echo', 'gemini stream call name')
    call check(res%message%tool_calls(1)%arguments == '{"text":"hi"}', &
      'gemini stream arguments')
    call check(res%usage%input_tokens == 4 .and. res%usage%output_tokens == 2, &
      'gemini stream usage')
    write(*, '(a)') 'fortran provider tests passed' 
  end subroutine
end module

program providers
  use provider_tests
  call run
end program
