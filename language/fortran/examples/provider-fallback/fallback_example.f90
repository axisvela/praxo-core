program fallback_example
  implicit none
  logical :: primary_ok, fallback_ok, fallback_called
  integer :: primary_calls, fallback_calls

  primary_ok = .true.
  fallback_ok = .true.
  fallback_called = .false.
  primary_calls = 1
  fallback_calls = 0
  if (.not. primary_ok) fallback_called = .true.
  if (fallback_called) stop 1

  primary_ok = .false.
  fallback_ok = .true.
  fallback_called = .false.
  if (.not. primary_ok) then
    fallback_called = .true.
    fallback_calls = 1
  end if
  if (.not. fallback_called .or. fallback_calls /= 1) stop 1

  primary_ok = .false.
  fallback_ok = .false.
  if (.not. primary_ok .and. .not. fallback_ok) continue
  print '(a)', 'Fortran provider fallback example passed'
end program
