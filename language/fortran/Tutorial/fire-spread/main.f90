program fire_spread
  implicit none
  real :: risk(3), threshold
  integer :: i, high_risk, modeled_spread

  risk = [0.2, 0.8, 0.5]
  threshold = 0.7
  high_risk = 0
  do i = 1, size(risk)
    if (risk(i) >= threshold) then
      high_risk = high_risk + 1
    end if
  end do
  modeled_spread = high_risk * 2

  write (*, '(A,I0)') 'cells=', size(risk)
  write (*, '(A,I0)') 'high_risk_cells=', high_risk
  write (*, '(A,I0)') 'modeled_spread=', modeled_spread
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,L1)') 'operational_warning=', .false.
  write (*, '(A,I0)') 'firebreak_dispatch=', 0
end program fire_spread
