module praxo_pattern
  use iso_c_binding, only: c_char, c_int, c_size_t
  use praxo_types, only: sdk_error
  use praxo_unicode, only: valid_utf8
  implicit none
  private
  public :: match_pattern
  interface
    function re2_match(pattern, pattern_size, text, text_size) bind(C, name='praxo_re2_match') result(status)
      import c_char, c_int, c_size_t
      character(kind=c_char), intent(in) :: pattern(*), text(*)
      integer(c_size_t), value :: pattern_size, text_size
      integer(c_int) :: status
    end function
  end interface
contains
  logical function match_pattern(pattern, text, error) result(matched)
    character(*), intent(in) :: pattern, text
    type(sdk_error), intent(out) :: error
    integer(c_int) :: status
    matched = .false.
    if (len(pattern) > 4096 .or. len(text) > 262144) then
      error%code = 'JSON_CAPACITY'
      return
    end if
    if (.not. valid_utf8(pattern) .or. .not. valid_utf8(text)) then
      error%code = 'JSON_INVALID'
      return
    end if
    status = re2_match(pattern, int(len(pattern), c_size_t), text, int(len(text), c_size_t))
    select case (status)
    case (0, 1)
      matched = status == 1
    case (2)
      error%code = 'SCHEMA_PATTERN_UNSUPPORTED'
    case (3)
      error%code = 'JSON_CAPACITY'
    case default
      error%code = 'SCHEMA_INVALID'
    end select
  end function
end module
