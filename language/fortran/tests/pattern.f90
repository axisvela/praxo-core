program pattern_tests
  use praxo_pattern
  use praxo_schema
  use praxo_types, only: sdk_error
  implicit none
  type(sdk_error) :: error
  type(validation_error), allocatable :: errors(:)
  character(:), allocatable :: han, greek, emoji, backslash
  logical :: matched
  integer :: checks = 0
  han = char(228)//char(189)//char(160)//char(229)//char(165)//char(189)
  greek = char(206)//char(177)//char(206)//char(178)
  emoji = char(240)//char(159)//char(152)//char(128)
  backslash = achar(92)

  call expect('^(ab|cd){2,3}$', 'abcdab', .true.)
  call expect('^(ab|cd){2,3}$', 'abcdabcd', .false.)
  call expect('^(?:ab|cd)+$', 'abcd', .true.)
  call expect('(?i)^hello$', 'HeLLo', .true.)
  call expect('(?s)^a.b$', 'a'//achar(10)//'b', .true.)
  call expect('a.b', 'a'//achar(10)//'b', .false.)
  call expect('(?m)^b$', 'a'//achar(10)//'b'//achar(10)//'c', .true.)
  call expect('a+?', 'xxaa', .true.)
  call expect('^a{0}$', '', .true.)
  call expect('^a{1000}$', repeat('a', 1000), .true.)
  call expect('^[[:alpha:]]+$', 'abcZ', .true.)
  call expect(backslash//'Q(a|b){2}'//backslash//'E', '(a|b){2}', .true.)
  call expect('', '', .true.)
  call expect('', han, .true.)
  call expect('^'//han//'$', han, .true.)
  call expect('^'//han//'$', han//'x', .false.)
  call expect('^'//backslash//'p{Han}+$', han, .true.)
  call expect('^'//backslash//'p{Greek}{2}$', greek, .true.)
  call expect('(?i)^'//char(206)//char(145)//'$', char(206)//char(177), .true.)
  call expect('^'//backslash//'p{L}+$', greek//han, .true.)
  call expect('^'//backslash//'P{L}+$', '123', .true.)
  call expect('^'//backslash//'p{Han}+$', greek, .false.)
  call expect('^.$', emoji, .true.)
  call expect('^'//backslash//'p{So}$', emoji, .true.)
  call expect('^.{2}$', emoji, .false.)
  call expect('^'//backslash//'x{1F600}$', emoji, .true.)
  call expect('^a'//achar(0)//'b$', 'a'//achar(0)//'b', .true.)
  call expect('^a$', 'a'//achar(0)//'b', .false.)
  call expect('b$', 'ab ', .false.)
  call expect('(a+)+$', repeat('a', 16000)//'!', .false.)
  call expect('^a+$', repeat('a', 262144), .true.)
  call expect('^(?:'//repeat('a?', 100)//')$', repeat('a', 262144), .false.)

  call invalid('(')
  call invalid('[z-a]')
  call invalid('a{1001}')
  call invalid('a'//backslash//'1')
  call invalid('(?=a)')
  call invalid(backslash//'p{NotAUnicodeClass}')
  call invalid(backslash)
  call invalid(char(255))
  matched = match_pattern('.', char(255), error)
  call check(error%failed() .and. .not. matched, 'invalid subject UTF-8')
  matched = match_pattern(repeat('a', 4097), 'a', error)
  call check(error%failed() .and. .not. matched, 'pattern byte limit')
  matched = match_pattern('a', repeat('a', 262145), error)
  call check(error%failed() .and. .not. matched, 'subject byte limit')

  call validate_schema('{"type":"string","pattern":"^\\p{Han}{2}$"}', &
    '"'//han//'"', errors, error)
  call check(.not. error%failed() .and. size(errors) == 0, 'Unicode property through schema')
  call validate_schema('{"type":"string","pattern":"^\\p{Han}{2}$"}', &
    '"'//greek//'"', errors, error)
  call check(.not. error%failed() .and. size(errors) == 1, 'schema Unicode non-match')
  call validate_schema('{"type":"string","pattern":"("}', '"a"', errors, error)
  call check(error%failed(), 'invalid schema pattern fails closed')
  print '(a,i0,a)', 'PASS: ', checks, ' native RE2/Unicode pattern assertions'
contains
  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    print '(a)', 'FAIL: '//label
    error stop 1
  end subroutine

  subroutine expect(pattern, text, wanted)
    character(*), intent(in) :: pattern, text
    logical, intent(in) :: wanted
    logical :: found
    found = match_pattern(pattern, text, error)
    call check(.not. error%failed() .and. (found .eqv. wanted), pattern)
  end subroutine

  subroutine invalid(pattern)
    character(*), intent(in) :: pattern
    logical :: found
    found = match_pattern(pattern, 'a', error)
    call check(error%failed() .and. .not. found, 'invalid RE2 syntax')
  end subroutine
end program
