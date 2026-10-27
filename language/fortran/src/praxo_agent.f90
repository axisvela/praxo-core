module praxo_agent
  use iso_fortran_env, only: int64
  use praxo_types
  use praxo_interfaces
  use praxo_context, only: context_budget
  use praxo_json
  use praxo_middleware
  implicit none
  private
  public :: agent_options, run_agent

  type :: agent_options
    class(model), pointer :: provider => null()
    type(registry), pointer :: tools => null()
    class(event_sink), pointer :: events => null()
    class(policy), pointer :: gate => null()
    character(:), allocatable :: system_prompt
    integer :: max_steps = 8
    integer(int64) :: max_tokens = 0
    type(context_budget) :: context
    type(call_limit), pointer :: limits => null()
    type(tool_selection), pointer :: selection => null()
    logical :: redact_emails = .false.
    logical :: redact_pii = .false.
  end type
contains
  subroutine run_agent(options, state, prompt, run_id, result, error)
    type(agent_options), intent(in) :: options
    type(session), intent(in) :: state
    character(*), intent(in) :: prompt, run_id
    type(run_result), intent(out) :: result
    type(sdk_error), intent(out) :: error
    type(request) :: req
    type(response) :: res
    type(tool_call) :: call
    type(message), allocatable :: compacted(:)
    type(json_document) :: arguments
    type(sdk_error) :: redaction_error
    character(:), allocatable :: output
    character(:), allocatable :: redacted
    integer :: steps, i, j, step_limit, call_count
    logical :: context_ok

    result%run_id = run_id
    result%output = ''
    if (.not. associated(options%provider) .or. len_trim(run_id) == 0) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    if (.not. allocated(state%id)) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    allocate(req%messages(0), req%tools(0))
    if (len(string_value(options%system_prompt)) > 0) then
      call append_message(req%messages, text_message('system', options%system_prompt))
    end if
    if (allocated(state%messages)) then
      do i = 1, size(state%messages)
        call append_message(req%messages, state%messages(i))
      end do
    end if
    call append_message(req%messages, text_message('user', prompt))
    if (associated(options%tools)) req%tools = options%tools%specs()
    if (associated(options%selection)) req%tools = options%selection%advertised(req%tools)
    step_limit = options%max_steps
    if (step_limit <= 0) step_limit = 8
    call emit('run.started')
    do steps = 1, step_limit
      if (.not. authorize('model.generate', '', '')) exit
      if (associated(options%limits)) then
        call options%limits%check(run_id, 'model', error)
        if (error%failed()) exit
      end if
      if (options%redact_emails .or. options%redact_pii) then
        do i = 1, size(req%messages)
          req%messages(i)%content = redact_pii(string_value(req%messages(i)%content))
          if (.not. allocated(req%messages(i)%tool_calls)) cycle
          do j = 1, size(req%messages(i)%tool_calls)
            output = '{}'
            if (allocated(req%messages(i)%tool_calls(j)%arguments)) output = req%messages(i)%tool_calls(j)%arguments
            redacted = redact_json_pii(output, error)
            if (error%failed()) exit
            req%messages(i)%tool_calls(j)%arguments = redacted
          end do
          if (error%failed()) exit
        end do
        if (error%failed()) exit
      end if
      call options%context%compact(req%messages, compacted, context_ok)
      if (.not. context_ok) then
        error%code = 'AGENT_CONTEXT_BUDGET'
        exit
      end if
      call move_alloc(compacted, req%messages)
      call options%provider%generate(req, res, error)
      if (error%failed()) exit
      result%steps = steps
      if (res%usage%input_tokens < 0 .or. res%usage%output_tokens < 0) then
        error%code = 'INVALID_REQUEST'
        exit
      end if
      if (res%usage%input_tokens > huge(0_int64) - result%usage%input_tokens .or. &
          res%usage%output_tokens > huge(0_int64) - result%usage%output_tokens) then
        error%code = 'AGENT_MAX_TOKENS'
        exit
      end if
      result%usage%input_tokens = result%usage%input_tokens + res%usage%input_tokens
      result%usage%output_tokens = result%usage%output_tokens + res%usage%output_tokens
      if (options%max_tokens > 0) then
        if (result%usage%input_tokens > options%max_tokens) then
          error%code = 'AGENT_MAX_TOKENS'
          exit
        end if
        if (result%usage%output_tokens > options%max_tokens - result%usage%input_tokens) then
          error%code = 'AGENT_MAX_TOKENS'
          exit
        end if
      end if
      call_count = 0
      if (allocated(res%message%tool_calls)) call_count = size(res%message%tool_calls)
      do i = 1, call_count
        output = '{}'
        if (allocated(res%message%tool_calls(i)%arguments)) output = res%message%tool_calls(i)%arguments
        call parse_json(output, arguments, error)
        if (error%failed()) exit
        if (json_kind(arguments, 1) /= 'O') then
          error%code = 'INVALID_REQUEST'
          exit
        end if
        res%message%tool_calls(i)%arguments = encode_json(arguments, 1, error)
        if (error%failed()) exit
      end do
      if (error%failed()) exit
      call append_message(req%messages, res%message)
      if (call_count == 0) then
        result%output = string_value(res%message%content)
        call emit('run.completed')
        return
      end if
      do i = 1, call_count
        call = res%message%tool_calls(i)
        if (len_trim(string_value(call%name)) == 0) then
          error%code = 'INVALID_REQUEST'
          exit
        end if
        if (associated(options%selection)) then
          call options%selection%check(call%name, error)
          if (error%failed()) exit
        end if
        if (.not. authorize('tool.invoke', call%name, string_value(call%arguments))) exit
        if (.not. associated(options%tools)) then
          error%code = 'TOOL_NOT_FOUND'
          exit
        end if
        if (.not. options%tools%has(call%name)) then
          error%code = 'TOOL_NOT_FOUND'
          exit
        end if
        if (associated(options%limits)) then
          call options%limits%check(run_id, 'tool', error)
          if (error%failed()) exit
        end if
        call emit('tool.call', call%name, string_value(call%arguments))
        call options%tools%invoke(call%name, string_value(call%arguments), output, error)
        if (error%failed()) exit
        if (.not. allocated(output)) output = ''
        if (options%redact_emails .or. options%redact_pii) then
          redacted = redact_json_pii(output, redaction_error)
          if (redaction_error%failed()) redacted = redact_pii(output)
          output = redacted
        end if
        call append_message(req%messages, text_message('tool', output, string_value(call%id)))
      end do
      if (error%failed()) exit
    end do
    if (.not. error%failed()) error%code = 'AGENT_MAX_STEPS'
    call emit('run.failed')
  contains
    logical function authorize(kind, name, arguments)
      character(*), intent(in) :: kind, name, arguments
      type(decision) :: verdict
      authorize = .true.
      if (.not. associated(options%gate)) return
      verdict = options%gate%check(action(kind, state%id, name, arguments))
      authorize = verdict%allowed
      if (.not. authorize) error%code = 'POLICY_ERROR'
    end function

    subroutine emit(kind, name, arguments)
      character(*), intent(in) :: kind
      character(*), optional, intent(in) :: name, arguments
      type(event) :: item
      if (.not. associated(options%events)) return
      item = event(kind, state%id, run_id, '', '')
      if (present(name)) item%tool_name = name
      if (present(arguments)) item%arguments = arguments
      call options%events%emit(item)
    end subroutine
  end subroutine

  subroutine append_message(messages, item)
    type(message), allocatable, intent(inout) :: messages(:)
    type(message), intent(in) :: item
    type(message), allocatable :: expanded(:)
    integer :: count
    count = size(messages)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = messages
    expanded(count + 1) = item
    call move_alloc(expanded, messages)
  end subroutine
end module
