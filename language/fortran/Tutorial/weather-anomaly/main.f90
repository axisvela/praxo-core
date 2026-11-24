program weather_anomaly
  implicit none
  real :: temps(7)
  real :: total, mean, threshold
  integer :: i, exceedances

  temps = [12.0, 14.0, 15.0, 22.0, 25.0, 19.0, 13.0]
  threshold = 20.0
  total = 0.0
  exceedances = 0
  do i = 1, size(temps)
    total = total + temps(i)
    if (temps(i) > threshold) then
      exceedances = exceedances + 1
    end if
  end do
  mean = total / real(size(temps))

  write (*, '(A,F6.1)') 'mean=', mean
  write (*, '(A,F6.1)') 'max=', maxval(temps)
  write (*, '(A,I0)') 'exceedances=', exceedances
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,I0)') 'warnings_sent=', 0
end program weather_anomaly
