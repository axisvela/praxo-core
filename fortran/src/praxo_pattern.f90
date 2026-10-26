module praxo_pattern
  use iso_fortran_env, only: int64
  use praxo_types, only: sdk_error
  implicit none
  private
  public :: match_pattern
contains
  logical function match_pattern(pattern, text, error) result(matched)
    character(*), intent(in) :: pattern, text
    type(sdk_error), intent(out) :: error
    logical, allocatable :: states(:), next(:)
    logical :: allowed(0:255), anchored, end_anchor, optional, repeated, negate
    integer :: cursor, i, first, last, code
    character :: byte
    matched = .false.
    if (len(pattern) > 4096 .or. len(text) > 262144) then
      error%code = 'JSON_CAPACITY'
      return
    end if
    if (int(len(pattern), int64) * len(text) > 16777216_int64) then
      error%code = 'JSON_CAPACITY'
      return
    end if
    do i = 1, len(text)
      if (iachar(text(i:i)) < 128) cycle
      error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
      return
    end do
    do i = 1, len(pattern)
      if (iachar(pattern(i:i)) < 128) cycle
      error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
      return
    end do
    allocate(states(0:len(text)), next(0:len(text)))
    cursor = 1
    anchored = .false.
    end_anchor = .false.
    if (len(pattern) > 0) anchored = pattern(1:1) == '^'
    states = .not. anchored
    states(0) = .true.
    if (anchored) cursor = cursor + 1
    do while (cursor <= len(pattern))
      byte = pattern(cursor:cursor)
      if (byte == '$' .and. cursor == len(pattern)) then
        end_anchor = .true.
        exit
      end if
      cursor = cursor + 1
      allowed = .false.
      select case (byte)
      case ('.')
        allowed = .true.
        allowed(10) = .false.
      case (achar(92))
        if (cursor > len(pattern)) then
          error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
          return
        end if
        byte = pattern(cursor:cursor)
        cursor = cursor + 1
        select case (byte)
        case ('d'); allowed(48:57) = .true.
        case ('w')
          allowed(48:57) = .true.
          allowed(65:90) = .true.
          allowed(97:122) = .true.
          allowed(95) = .true.
        case ('s')
          allowed(9:13) = .true.
          allowed(32) = .true.
        case ('t'); allowed(9) = .true.
        case ('n'); allowed(10) = .true.
        case ('r'); allowed(13) = .true.
        case ('f'); allowed(12) = .true.
        case default
          if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', byte) > 0) then
            error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
            return
          end if
          allowed(iachar(byte)) = .true.
        end select
      case ('[')
        negate = .false.
        if (cursor <= len(pattern)) negate = pattern(cursor:cursor) == '^'
        if (negate) cursor = cursor + 1
        first = cursor
        do while (cursor <= len(pattern))
          if (pattern(cursor:cursor) == ']') exit
          if (pattern(cursor:cursor) == achar(92)) then
            error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
            return
          end if
          code = iachar(pattern(cursor:cursor))
          cursor = cursor + 1
          if (cursor + 1 <= len(pattern)) then
            if (pattern(cursor:cursor) == '-' .and. pattern(cursor + 1:cursor + 1) /= ']') then
              last = iachar(pattern(cursor + 1:cursor + 1))
              if (last < code) then
                error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
                return
              end if
              allowed(code:last) = .true.
              cursor = cursor + 2
              cycle
            end if
          end if
          allowed(code) = .true.
        end do
        if (cursor > len(pattern) .or. cursor == first) then
          error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
          return
        end if
        if (pattern(cursor:cursor) /= ']') then
          error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
          return
        end if
        cursor = cursor + 1
        if (negate) allowed = .not. allowed
      case ('(', ')', '|', '{', '}', '*', '+', '?', '^', '$')
        error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
        return
      case default
        allowed(iachar(byte)) = .true.
      end select
      optional = .false.
      repeated = .false.
      if (cursor <= len(pattern)) then
        byte = pattern(cursor:cursor)
        if (byte == '*' .or. byte == '?' .or. byte == '+') then
          optional = byte /= '+'
          repeated = byte /= '?'
          cursor = cursor + 1
        end if
      end if
      next = .false.
      if (optional) next = states
      do i = 1, len(text)
        if (.not. allowed(iachar(text(i:i)))) cycle
        next(i) = next(i) .or. states(i - 1)
        if (repeated) next(i) = next(i) .or. next(i - 1)
      end do
      states = next
    end do
    if (cursor <= len(pattern) .and. .not. end_anchor) then
      error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
      return
    end if
    if (end_anchor) then
      matched = states(len(text))
    else
      matched = any(states)
    end if
  end function
end module
