program mining_slope
  implicit none
  real :: displacement(3), threshold, peak
  integer :: i, flagged

  displacement = [2.0, 7.0, 4.0]
  threshold = 5.0
  flagged = 0
  peak = displacement(1)
  do i = 1, size(displacement)
    if (displacement(i) > threshold) then
      flagged = flagged + 1
    end if
    if (displacement(i) > peak) then
      peak = displacement(i)
    end if
  end do

  write (*, '(A,I0)') 'stations=', size(displacement)
  write (*, '(A,I0)') 'flagged=', flagged
  write (*, '(A,F6.1)') 'max_displacement_mm=', peak
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,L1)') 'collapse_prediction=', .false.
  write (*, '(A,I0)') 'vehicle_dispatches=', 0
end program mining_slope
