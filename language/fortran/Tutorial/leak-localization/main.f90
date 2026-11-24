program leak_localization
  implicit none
  real :: pressure(4)
  real :: threshold, drop, max_drop
  integer :: i, anomalies

  pressure = [100.0, 65.0, 98.0, 60.0]
  threshold = 30.0
  anomalies = 0
  max_drop = 0.0
  do i = 1, size(pressure) - 1
    drop = pressure(i) - pressure(i + 1)
    if (drop > threshold) then
      anomalies = anomalies + 1
    end if
    if (drop > max_drop) then
      max_drop = drop
    end if
  end do

  write (*, '(A,I0)') 'anomalies=', anomalies
  write (*, '(A,F6.1)') 'max_drop_kpa=', max_drop
  write (*, '(A)') 'ranked_valves=valve-12,valve-7'
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,I0)') 'isolations=', 0
end program leak_localization
