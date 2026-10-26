module praxo_unicode
  use praxo_types, only: sdk_error
  implicit none
  private
  public :: valid_utf8, quote_json, decode_json_string, unicode_length
contains
  logical function valid_utf8(text) result(valid)
    character(*), intent(in) :: text
    integer :: i, byte, remaining, low, high
    valid = .false.
    remaining = 0
    low = 128
    high = 191
    do i = 1, len(text)
      byte = iachar(text(i:i))
      if (remaining > 0) then
        if (byte < low .or. byte > high) return
        remaining = remaining - 1
        low = 128
        high = 191
      else
        select case (byte)
        case (0:127)
          cycle
        case (194:223)
          remaining = 1
        case (224:239)
          remaining = 2
          if (byte == 224) low = 160
          if (byte == 237) high = 159
        case (240:244)
          remaining = 3
          if (byte == 240) low = 144
          if (byte == 244) high = 143
        case default
          return
        end select
      end if
    end do
    valid = remaining == 0
  end function

  integer function unicode_length(text) result(count)
    character(*), intent(in) :: text
    integer :: i, byte
    count = 0
    do i = 1, len(text)
      byte = iachar(text(i:i))
      if (byte < 128 .or. byte >= 192) count = count + 1
    end do
  end function

  function quote_json(text, error) result(output)
    character(*), intent(in) :: text
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: output
    character(:), allocatable :: buffer
    character(*), parameter :: hex = '0123456789abcdef'
    integer :: i, cursor, byte
    output = ''
    if (.not. valid_utf8(text)) then
      error%code = 'JSON_INVALID'
      return
    end if
    if (len(text) > 262144) then
      error%code = 'JSON_CAPACITY'
      return
    end if
    allocate(character(6 * len(text) + 2) :: buffer)
    cursor = 2
    buffer(1:1) = '"'
    do i = 1, len(text)
      byte = iachar(text(i:i))
      if (byte < 32) then
        buffer(cursor:cursor + 3) = achar(92)//'u00'
        buffer(cursor + 4:cursor + 4) = hex(byte / 16 + 1:byte / 16 + 1)
        buffer(cursor + 5:cursor + 5) = hex(mod(byte, 16) + 1:mod(byte, 16) + 1)
        cursor = cursor + 6
      else
        if (byte == 34 .or. byte == 92) then
          buffer(cursor:cursor) = achar(92)
          cursor = cursor + 1
        end if
        buffer(cursor:cursor) = text(i:i)
        cursor = cursor + 1
      end if
    end do
    buffer(cursor:cursor) = '"'
    output = buffer(:cursor)
  end function

  subroutine decode_json_string(raw, cursor, text, error)
    character(*), intent(in) :: raw
    integer, intent(inout) :: cursor
    character(:), allocatable, intent(out) :: text
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: buffer, encoded
    character :: byte
    integer :: used, point, high
    logical :: closed
    text = ''
    if (cursor < 1 .or. cursor > len(raw)) then
      error%code = 'JSON_INVALID'
      return
    end if
    if (raw(cursor:cursor) /= '"') then
      error%code = 'JSON_INVALID'
      return
    end if
    allocate(character(len(raw)) :: buffer)
    cursor = cursor + 1
    used = 0
    closed = .false.
    do while (cursor <= len(raw))
      byte = raw(cursor:cursor)
      cursor = cursor + 1
      if (byte == '"') then
        closed = .true.
        exit
      end if
      if (iachar(byte) < 32) exit
      if (byte /= achar(92)) then
        used = used + 1
        buffer(used:used) = byte
        cycle
      end if
      if (cursor > len(raw)) exit
      byte = raw(cursor:cursor)
      cursor = cursor + 1
      select case (byte)
      case ('"', '/', achar(92))
        encoded = byte
      case ('b')
        encoded = achar(8)
      case ('f')
        encoded = achar(12)
      case ('n')
        encoded = achar(10)
      case ('r')
        encoded = achar(13)
      case ('t')
        encoded = achar(9)
      case ('u')
        point = hex_point()
        if (error%failed()) return
        if (point >= 55296 .and. point <= 56319) then
          high = point
          if (cursor + 5 > len(raw)) exit
          if (raw(cursor:cursor + 1) /= achar(92)//'u') exit
          cursor = cursor + 2
          point = hex_point()
          if (error%failed()) return
          if (point < 56320 .or. point > 57343) exit
          point = 65536 + (high - 55296) * 1024 + point - 56320
        else if (point >= 56320 .and. point <= 57343) then
          exit
        end if
        encoded = encode_point(point)
      case default
        exit
      end select
      buffer(used + 1:used + len(encoded)) = encoded
      used = used + len(encoded)
    end do
    if (.not. closed) then
      error%code = 'JSON_INVALID'
      return
    end if
    if (.not. valid_utf8(buffer(:used))) then
      error%code = 'JSON_INVALID'
      return
    end if
    text = buffer(:used)
  contains
    integer function hex_point() result(value)
      integer :: i, digit, code
      value = 0
      if (cursor + 3 > len(raw)) then
        error%code = 'JSON_INVALID'
        return
      end if
      do i = 1, 4
        code = iachar(raw(cursor:cursor))
        digit = -1
        if (code >= 48 .and. code <= 57) digit = code - 48
        if (code >= 65 .and. code <= 70) digit = code - 55
        if (code >= 97 .and. code <= 102) digit = code - 87
        if (digit < 0) then
          error%code = 'JSON_INVALID'
          return
        end if
        value = value * 16 + digit
        cursor = cursor + 1
      end do
    end function
  end subroutine

  function encode_point(point) result(text)
    integer, intent(in) :: point
    character(:), allocatable :: text
    if (point < 128) then
      text = achar(point)
    else if (point < 2048) then
      text = achar(192 + point / 64)//achar(128 + mod(point, 64))
    else if (point < 65536) then
      text = achar(224 + point / 4096)//achar(128 + mod(point / 64, 64))//achar(128 + mod(point, 64))
    else
      text = achar(240 + point / 262144)//achar(128 + mod(point / 4096, 64)) &
        //achar(128 + mod(point / 64, 64))//achar(128 + mod(point, 64))
    end if
  end function
end module
