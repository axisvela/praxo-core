program dispatch_review
  implicit none
  real :: demand, charge, discharge, net
  real :: min_level, max_level, level
  logical :: within_limits
  integer :: shortfall

  demand = 65.0
  charge = 40.0
  discharge = 30.0
  min_level = 10.0
  max_level = 100.0
  level = 55.0 + charge - discharge
  net = discharge - demand
  within_limits = level >= min_level .and. level <= max_level
  shortfall = 0
  if (net < 0.0) then
    shortfall = int(-net)
  end if

  write (*, '(A,I0)') 'shortfall_mw=', shortfall
  write (*, '(A,L1)') 'within_limits=', within_limits
  write (*, '(A,F6.1)') 'level=', level
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,I0)') 'grid_commands=', 0
end program dispatch_review
