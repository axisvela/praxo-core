program retry_example
  implicit none
  integer :: calls, attempt, status

  calls = 0
  status = 1
  do attempt = 1, 3
    calls = calls + 1
    if (calls > 2) then
      status = 0
      exit
    end if
  end do
  if (status /= 0 .or. calls /= 3) stop 1

  calls = 0
  status = 1
  do attempt = 1, 3
    calls = calls + 1
    status = 1
  end do
  if (status /= 1 .or. calls /= 3) stop 1

  print '(a)', 'Fortran retry example passed'
end program
