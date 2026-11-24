program eda_placement
  implicit none
  integer :: grid_size, placed, overlaps
  real :: wirelength_proxy
  logical :: within_grid

  grid_size = 4
  placed = 3
  overlaps = 0
  wirelength_proxy = 12.5
  within_grid = placed <= grid_size * grid_size .and. overlaps == 0

  write (*, '(A,I0)') 'grid_size=', grid_size
  write (*, '(A,I0)') 'placed=', placed
  write (*, '(A,I0)') 'overlaps=', overlaps
  write (*, '(A,L1)') 'within_grid=', within_grid
  write (*, '(A,F6.1)') 'wirelength_proxy=', wirelength_proxy
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,L1)') 'foundry_valid=', .false.
end program eda_placement
