module praxo_toolcall
  use praxo_types
  use praxo_json
  implicit none
  private
  public :: parsed_tool_call, parse_tool_call, parse_input_json, strip_markup

  type :: parsed_tool_call
    logical :: found = .false.
    character(:), allocatable :: name, input, call_id, operation, resource, risk, reason, idempotency_key
  end type
contains
  function parse_input_json(raw, error) result(output)
    character(*), intent(in) :: raw
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: output
    type(json_document) :: doc
    output = ''
    call parse_json(trim(adjustl(raw)), doc, error)
    if (error%failed()) return
    if (json_kind(doc, 1) /= 'O') then
      error%code = 'INVALID_REQUEST'
      return
    end if
    output = encode_json(doc, 1, error)
  end function

  function parse_tool_call(content) result(call)
    character(*), intent(in) :: content
    type(parsed_tool_call) :: call
    type(json_document) :: doc
    type(sdk_error) :: error
    character(:), allocatable :: text, name, body, closing, tag
    integer :: node, start, finish, opening, body_start, ending, blank
    call%name = ''
    call%input = '{}'
    call%call_id = ''
    call%operation = ''
    call%resource = ''
    call%risk = ''
    call%reason = ''
    call%idempotency_key = ''
    call parse_json(content, doc, error)
    if (.not. error%failed()) then
      node = json_get(doc, 1, 'name')
      if (json_kind(doc, node) == 'S' .and. len(json_text(doc, node)) > 0) then
        call%name = json_text(doc, node)
        node = json_get(doc, 1, 'input')
        if (json_kind(doc, node) == 'O') call%input = encode_json(doc, node, error)
        call%call_id = field('call_id')
        call%operation = field('operation')
        call%resource = field('resource')
        call%risk = field('risk')
        call%reason = field('reason')
        call%idempotency_key = field('idempotency_key')
        call%found = .not. error%failed()
        return
      end if
    end if
    text = trim(adjustl(content))
    start = index(text, '<tool_call ')
    if (start > 0) then
      finish = index(text(start:), '>')
      if (finish > 0) then
        finish = finish + start - 1
        tag = text(start:finish)
        opening = index(tag, 'name="')
        if (opening > 0) then
          opening = opening + 6
          ending = index(tag(opening:), '"')
          if (ending > 1) then
            name = tag(opening:opening + ending - 2)
            body_start = finish + 1
            ending = index(text(body_start:), '</tool_call>')
            if (ending > 0) then
              body = text(body_start:body_start + ending - 2)
              call%input = parse_input_json(body, error)
              if (.not. error%failed()) then
                call%name = name
                call%found = .true.
                return
              end if
            end if
          end if
        end if
      end if
    end if
    start = index(text, '<')
    if (start > 0) then
      finish = index(text(start:), '>')
      if (finish > 1) then
        finish = finish + start - 1
        name = text(start + 1:finish - 1)
        if (dotted_name(name)) then
          closing = '</'//name//'>'
          ending = index(text(finish + 1:), closing)
          if (ending > 0) then
            body = text(finish + 1:finish + ending - 1)
            call%input = parse_input_json(body, error)
            if (.not. error%failed()) then
              call%name = name
              call%found = .true.
              return
            end if
          end if
        end if
      end if
    end if
    blank = scan(text, ' '//achar(9)//achar(10))
    if (blank > 1) then
      name = text(:blank - 1)
      if (dotted_name(name)) then
        call%input = parse_input_json(text(blank + 1:), error)
        if (.not. error%failed()) then
          call%name = name
          call%found = .true.
        end if
      end if
    end if
  contains
    function field(key) result(value)
      character(*), intent(in) :: key
      character(:), allocatable :: value
      integer :: index
      index = json_get(doc, 1, key)
      value = ''
      if (json_kind(doc, index) == 'S') value = json_text(doc, index)
    end function
  end function

  logical function dotted_name(name) result(valid)
    character(*), intent(in) :: name
    integer :: i, code
    valid = .false.
    if (len(name) < 3 .or. index(name, '.') == 0) return
    if (name(1:1) == '.' .or. name(len(name):) == '.') return
    do i = 1, len(name)
      code = iachar(name(i:i))
      if (code >= 65 .and. code <= 90) cycle
      if (code >= 97 .and. code <= 122) cycle
      if (code >= 48 .and. code <= 57) cycle
      if (name(i:i) == '_' .or. name(i:i) == '-' .or. name(i:i) == '.') cycle
      return
    end do
    valid = .true.
  end function

  function strip_markup(content) result(output)
    character(*), intent(in) :: content
    character(:), allocatable :: output, name, closing
    integer :: cursor, opening, finish, ending
    output = content
    cursor = 1
    do while (cursor <= len(output))
      opening = index(output(cursor:), '<')
      if (opening == 0) exit
      opening = opening + cursor - 1
      finish = index(output(opening:), '>')
      if (finish == 0) exit
      finish = finish + opening - 1
      name = output(opening + 1:finish - 1)
      closing = ''
      if (index(name, 'tool_call ') == 1 .or. name == 'tool_call') closing = '</tool_call>'
      if (name == 'tool_call_invoke') closing = '</tool_call_invoke>'
      if (dotted_name(name)) closing = '</'//name//'>'
      if (len(closing) == 0) then
        cursor = finish + 1
        cycle
      end if
      ending = index(output(finish + 1:), closing)
      if (ending == 0) then
        output = output(:opening - 1)
        exit
      end if
      ending = finish + ending + len(closing)
      output = output(:opening - 1)//output(ending:)
      cursor = opening
    end do
    output = trim(adjustl(output))
  end function
end module
