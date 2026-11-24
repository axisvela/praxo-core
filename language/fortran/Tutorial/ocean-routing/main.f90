program ocean_routing
  implicit none
  real :: base_cost(2), weather_cost(2), total(2)
  integer :: selected

  base_cost = [1200.0, 980.0]
  weather_cost = [100.0, 150.0]
  total = base_cost + weather_cost
  selected = 1
  if (total(2) < total(1)) then
    selected = 2
  end if

  write (*, '(A,F6.1)') 'route_1_cost=', total(1)
  write (*, '(A,F6.1)') 'route_2_cost=', total(2)
  write (*, '(A,I0)') 'selected_route=', selected
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,L1)') 'fuel_savings_claim=', .false.
  write (*, '(A,I0)') 'navigation_commands=', 0
end program ocean_routing
