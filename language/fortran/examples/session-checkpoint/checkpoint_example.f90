module session_checkpoint_types
  use praxo_types
  use praxo_interfaces
  use praxo_unicode, only: quote_json
  use praxo_json
  implicit none

  type, extends(model) :: turn_model
    integer :: calls = 0
  contains
    procedure :: generate => generate_turn
  end type
contains
  subroutine generate_turn(self, req, res, error)
    class(turn_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    character(32) :: count
    self%calls = self%calls + 1
    write(count, '(i0)') size(req%messages)
    res%message = text_message('assistant', 'turn '//trim(adjustl(count)))
    error%code = ''
  end subroutine

  subroutine append_message(messages, item)
    type(message), allocatable, intent(inout) :: messages(:)
    type(message), intent(in) :: item
    type(message), allocatable :: expanded(:)
    integer :: count
    count = 0
    if (allocated(messages)) count = size(messages)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = messages
    expanded(count + 1) = item
    call move_alloc(expanded, messages)
  end subroutine

  function encode_history(messages) result(text)
    type(message), intent(in) :: messages(:)
    character(:), allocatable :: text
    type(sdk_error) :: error
    character(:), allocatable :: role, content
    integer :: i
    text = '['
    do i = 1, size(messages)
      if (i > 1) text = text//','
      role = quote_json(messages(i)%role, error)
      if (error%failed()) return
      content = quote_json(messages(i)%content, error)
      if (error%failed()) return
      text = text//'{"role":'//role//',"content":'//content//'}'
    end do
    text = text//']'
  end function

  subroutine decode_history(raw, messages, error)
    character(*), intent(in) :: raw
    type(message), allocatable, intent(out) :: messages(:)
    type(sdk_error), intent(out) :: error
    type(json_document) :: doc
    integer, allocatable :: items(:)
    integer :: i
    call parse_json(raw, doc, error)
    if (error%failed()) return
    items = json_children(doc, 1)
    allocate(messages(size(items)))
    do i = 1, size(items)
      messages(i) = text_message(json_text(doc, json_get(doc, items(i), 'role')), &
        json_text(doc, json_get(doc, items(i), 'content')))
    end do
  end subroutine
end module

program session_checkpoint_example
  use praxo_types
  use praxo_agent, only: agent_options, run_agent
  use praxo_checkpoint, only: checkpoint_allowlist
  use praxo_json, only: parse_json, encode_json, json_get, json_document
  use session_checkpoint_types
  implicit none

  type(turn_model), target :: provider
  type(agent_options) :: options
  type(session) :: state
  type(run_result) :: result
  type(sdk_error) :: error
  type(checkpoint_allowlist) :: allow
  type(json_document) :: doc
  character(:), allocatable :: envelope, payload, messages_json
  integer :: restored_count

  state%id = 'session-1'
  allocate(state%messages(2))
  state%messages(1) = text_message('user', 'first')
  state%messages(2) = text_message('assistant', 'ack')

  options%provider => provider
  call run_agent(options, state, 'second', 'run-2', result, error)
  if (error%failed() .or. result%output /= 'turn 3') stop 1
  call append_message(state%messages, text_message('user', 'second'))
  call append_message(state%messages, text_message('assistant', result%output))

  call allow%register('session', error)
  if (error%failed()) stop 1
  payload = '{"messages":'//encode_history(state%messages)//'}'
  envelope = allow%marshal('session', payload, error)
  if (error%failed()) stop 1
  payload = allow%unmarshal(envelope, error)
  if (error%failed()) stop 1
  call parse_json(payload, doc, error)
  if (error%failed()) stop 1
  messages_json = encode_json(doc, json_get(doc, 1, 'messages'), error)
  if (error%failed()) stop 1
  call decode_history(messages_json, state%messages, error)
  if (error%failed()) stop 1
  restored_count = size(state%messages)

  call run_agent(options, state, 'third', 'run-3', result, error)
  if (error%failed() .or. result%output /= 'turn 5') stop 1

  print '(a,i0)', 'restored messages: ', restored_count
  print '(a)', 'output: '//result%output
end program
