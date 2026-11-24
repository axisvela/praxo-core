program pollution_tracing
  implicit none
  real :: pm25(3)
  real :: peak
  integer :: i, peak_index

  pm25 = [48.0, 35.0, 22.0]
  peak = pm25(1)
  peak_index = 1
  do i = 2, size(pm25)
    if (pm25(i) > peak) then
      peak = pm25(i)
      peak_index = i
    end if
  end do

  write (*, '(A,I0)') 'sensors=', size(pm25)
  write (*, '(A,I0)') 'peak_sensor_index=', peak_index
  write (*, '(A,F6.1)') 'peak_pm25=', peak
  write (*, '(A,I0)') 'hypotheses=', 2
  write (*, '(A,L1)') 'confidence_claimed=', .false.
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,I0)') 'enforcement_findings=', 0
end program pollution_tracing
