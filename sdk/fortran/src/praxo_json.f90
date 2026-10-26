module praxo_json
  use iso_fortran_env, only: real64, int64
  use ieee_arithmetic, only: ieee_is_finite
  use praxo_types, only: sdk_error, same_string
  use praxo_unicode
  implicit none
  private
  public :: json_node, json_document, parse_json, encode_json, json_get, json_children
  public :: json_kind, json_text, json_real, json_equal

  type :: json_node
    character :: kind = 'Z'
    integer :: parent = 0
    character(:), allocatable :: name, text
  end type

  type :: json_document
    type(json_node), allocatable :: nodes(:)
  end type
contains
  subroutine parse_json(raw, doc, error)
    character(*), intent(in) :: raw
    type(json_document), intent(out) :: doc
    type(sdk_error), intent(out) :: error
    integer :: cursor, count
    cursor = 1
    count = 0
    allocate(doc%nodes(4096))
    if (len(raw) > 262144) then
      error%code = 'JSON_CAPACITY'
    else
      call value(0, '', 0)
      call whitespace()
      if (cursor <= len(raw) .and. .not. error%failed()) error%code = 'JSON_INVALID'
    end if
    if (error%failed()) count = 0
    doc%nodes = doc%nodes(:count)
  contains
    function peek() result(byte)
      character :: byte
      byte = achar(0)
      if (cursor <= len(raw)) byte = raw(cursor:cursor)
    end function

    subroutine whitespace()
      do while (cursor <= len(raw))
        select case (raw(cursor:cursor))
        case (' ', achar(9), achar(10), achar(13))
          cursor = cursor + 1
        case default
          exit
        end select
      end do
    end subroutine

    recursive subroutine value(parent, name, depth)
      integer, intent(in) :: parent, depth
      character(*), intent(in) :: name
      integer :: node, start
      character :: opening, closing
      character(:), allocatable :: key, text
      if (error%failed()) return
      call whitespace()
      if (cursor > len(raw)) then
        error%code = 'JSON_INVALID'
        return
      end if
      if (depth > 64 .or. count >= 4096) then
        error%code = 'JSON_CAPACITY'
        return
      end if
      count = count + 1
      node = count
      doc%nodes(node)%parent = parent
      doc%nodes(node)%name = name
      doc%nodes(node)%text = ''
      opening = peek()
      select case (opening)
      case ('{', '[')
        if (depth >= 64) then
          error%code = 'JSON_CAPACITY'
          return
        end if
        closing = ']'
        doc%nodes(node)%kind = 'A'
        if (opening == '{') then
          closing = '}'
          doc%nodes(node)%kind = 'O'
        end if
        cursor = cursor + 1
        call whitespace()
        if (peek() == closing) then
          cursor = cursor + 1
          return
        end if
        do
          key = ''
          if (opening == '{') then
            call decode_json_string(raw, cursor, key, error)
            if (error%failed()) return
            call whitespace()
            if (peek() /= ':') exit
            cursor = cursor + 1
          end if
          call value(node, key, depth + 1)
          if (error%failed()) return
          call whitespace()
          if (peek() == closing) then
            cursor = cursor + 1
            return
          end if
          if (peek() /= ',') exit
          cursor = cursor + 1
          call whitespace()
        end do
        error%code = 'JSON_INVALID'
      case ('"')
        doc%nodes(node)%kind = 'S'
        call decode_json_string(raw, cursor, text, error)
        if (.not. error%failed()) doc%nodes(node)%text = text
      case ('t')
        call fixed(node, 'true', 'T')
      case ('f')
        call fixed(node, 'false', 'F')
      case ('n')
        call fixed(node, 'null', 'Z')
      case default
        doc%nodes(node)%kind = 'N'
        start = cursor
        if (peek() == '-') cursor = cursor + 1
        if (peek() == '0') then
          cursor = cursor + 1
        else
          if (peek() < '1' .or. peek() > '9') then
            error%code = 'JSON_INVALID'
            return
          end if
          call digits()
        end if
        if (peek() == '.') then
          cursor = cursor + 1
          call required_digits()
        end if
        if (peek() == 'e' .or. peek() == 'E') then
          cursor = cursor + 1
          if (peek() == '+' .or. peek() == '-') cursor = cursor + 1
          call required_digits()
        end if
        doc%nodes(node)%text = raw(start:cursor - 1)
      end select
    end subroutine

    subroutine digits()
      do while (peek() >= '0' .and. peek() <= '9')
        cursor = cursor + 1
      end do
    end subroutine

    subroutine required_digits()
      if (peek() < '0' .or. peek() > '9') error%code = 'JSON_INVALID'
      call digits()
    end subroutine

    subroutine fixed(node, text, kind)
      integer, intent(in) :: node
      character(*), intent(in) :: text
      character, intent(in) :: kind
      if (cursor + len(text) - 1 > len(raw)) then
        error%code = 'JSON_INVALID'
        return
      end if
      if (raw(cursor:cursor + len(text) - 1) /= text) then
        error%code = 'JSON_INVALID'
        return
      end if
      doc%nodes(node)%kind = kind
      doc%nodes(node)%text = text
      cursor = cursor + len(text)
    end subroutine
  end subroutine

  integer function json_get(doc, parent, name) result(node)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: parent
    character(*), intent(in) :: name
    integer :: i
    node = 0
    if (json_kind(doc, parent) /= 'O') return
    do i = parent + 1, size(doc%nodes)
      if (doc%nodes(i)%parent /= parent) cycle
      if (same_string(doc%nodes(i)%name, name)) node = i
    end do
  end function

  function json_children(doc, parent) result(children)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: parent
    integer, allocatable :: children(:)
    integer :: i, total
    allocate(children(0))
    if (json_kind(doc, parent) /= 'O' .and. json_kind(doc, parent) /= 'A') return
    total = count(doc%nodes%parent == parent)
    deallocate(children)
    allocate(children(total))
    total = 0
    do i = parent + 1, size(doc%nodes)
      if (doc%nodes(i)%parent /= parent) cycle
      total = total + 1
      children(total) = i
    end do
  end function

  function json_kind(doc, node) result(kind)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: node
    character :: kind
    kind = ' '
    if (.not. allocated(doc%nodes)) return
    if (node < 1 .or. node > size(doc%nodes)) return
    kind = doc%nodes(node)%kind
  end function

  function json_text(doc, node) result(text)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: node
    character(:), allocatable :: text
    text = ''
    if (json_kind(doc, node) == ' ') return
    if (allocated(doc%nodes(node)%text)) text = doc%nodes(node)%text
  end function

  function json_real(doc, node, ok) result(value)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: node
    logical, intent(out) :: ok
    real(real64) :: value
    integer :: status
    value = 0
    ok = .false.
    if (json_kind(doc, node) /= 'N') return
    read(doc%nodes(node)%text, *, iostat=status) value
    if (status /= 0) return
    ok = ieee_is_finite(value)
  end function

  function encode_json(doc, node, error) result(output)
    type(json_document), intent(in) :: doc
    integer, intent(in) :: node
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: output
    type(json_document) :: validated
    output = encode(node, 0)
    if (.not. error%failed()) call parse_json(output, validated, error)
    if (error%failed()) output = ''
  contains
    recursive function encode(current, depth) result(text)
      integer, intent(in) :: current, depth
      character(:), allocatable :: text, item, key
      type(json_document) :: scalar
      integer, allocatable :: children(:)
      integer :: i
      text = ''
      if (error%failed()) return
      if (depth > 64 .or. json_kind(doc, current) == ' ') then
        error%code = 'JSON_INVALID'
        return
      end if
      select case (json_kind(doc, current))
      case ('S')
        text = quote_json(json_text(doc, current), error)
      case ('N')
        text = json_text(doc, current)
        call parse_json(text, scalar, error)
        if (error%failed()) return
        if (size(scalar%nodes) /= 1 .or. json_kind(scalar, 1) /= 'N') error%code = 'JSON_INVALID'
      case ('T')
        text = 'true'
      case ('F')
        text = 'false'
      case ('Z')
        text = 'null'
      case ('O', 'A')
        children = json_children(doc, current)
        text = '['
        if (json_kind(doc, current) == 'O') text = '{'
        do i = 1, size(children)
          if (i > 1) text = text//','
          if (json_kind(doc, current) == 'O') then
            key = quote_json(doc%nodes(children(i))%name, error)
            if (error%failed()) return
            text = text//key//':'
          end if
          item = encode(children(i), depth + 1)
          if (error%failed()) return
          text = text//item
          if (len(text) > 262144) then
            error%code = 'JSON_CAPACITY'
            return
          end if
        end do
        if (json_kind(doc, current) == 'O') then
          text = text//'}'
        else
          text = text//']'
        end if
      case default
        error%code = 'JSON_INVALID'
      end select
    end function
  end function

  recursive logical function json_equal(a, ai, b, bi) result(equal)
    type(json_document), intent(in) :: a, b
    integer, intent(in) :: ai, bi
    integer, allocatable :: ac(:), bc(:)
    integer :: i, other, unique_a, unique_b
    equal = .false.
    if (json_kind(a, ai) == ' ' .or. json_kind(a, ai) /= json_kind(b, bi)) return
    select case (json_kind(a, ai))
    case ('A', 'O')
      ac = json_children(a, ai)
      bc = json_children(b, bi)
      if (json_kind(a, ai) == 'A' .and. size(ac) /= size(bc)) return
      unique_a = 0
      unique_b = 0
      do i = 1, size(ac)
        if (json_kind(a, ai) == 'O') then
          if (json_get(a, ai, a%nodes(ac(i))%name) /= ac(i)) cycle
          other = json_get(b, bi, a%nodes(ac(i))%name)
        else
          other = bc(i)
        end if
        unique_a = unique_a + 1
        if (.not. json_equal(a, ac(i), b, other)) return
      end do
      do i = 1, size(bc)
        if (json_kind(b, bi) == 'O') then
          if (json_get(b, bi, b%nodes(bc(i))%name) /= bc(i)) cycle
        end if
        unique_b = unique_b + 1
      end do
      equal = unique_a == unique_b
    case ('N')
      equal = same_string(number_key(json_text(a, ai)), number_key(json_text(b, bi)))
    case default
      equal = same_string(json_text(a, ai), json_text(b, bi))
    end select
  end function

  function number_key(raw) result(key)
    character(*), intent(in) :: raw
    character(:), allocatable :: key, digits, sign
    character(32) :: formatted
    integer :: first, last, marker, dot, trailing, status
    integer(int64) :: exponent, fraction
    key = '!'//raw
    if (len(raw) == 0) return
    first = 1
    sign = ''
    if (raw(1:1) == '-') then
      sign = '-'
      first = 2
    end if
    marker = scan(raw, 'eE')
    last = len(raw)
    if (marker > 0) last = marker - 1
    digits = raw(first:last)
    dot = index(digits, '.')
    fraction = 0
    if (dot > 0) then
      fraction = len(digits) - dot
      digits = digits(:dot - 1)//digits(dot + 1:)
    end if
    first = verify(digits, '0')
    if (first == 0) then
      key = '0'
      return
    end if
    digits = digits(first:)
    last = len(digits)
    do while (last > 1)
      if (digits(last:last) /= '0') exit
      last = last - 1
    end do
    trailing = len(digits) - last
    exponent = 0
    if (marker > 0) then
      read(raw(marker + 1:), *, iostat=status) exponent
      if (status /= 0) return
    end if
    if (exponent < -huge(exponent) + len(raw) .or. exponent > huge(exponent) - len(raw)) return
    exponent = exponent - fraction + trailing
    write(formatted, '(i0)') exponent
    key = sign//digits(:last)//'e'//trim(formatted)
  end function
end module
