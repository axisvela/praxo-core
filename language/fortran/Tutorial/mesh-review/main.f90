program mesh_review
  implicit none
  integer :: nodes, max_nodes, triangles, overlaps
  logical :: within_constraints

  nodes = 3
  max_nodes = 4
  triangles = 2
  overlaps = 0
  within_constraints = nodes <= max_nodes .and. overlaps == 0

  write (*, '(A,I0)') 'nodes=', nodes
  write (*, '(A,I0)') 'triangles=', triangles
  write (*, '(A,I0)') 'overlaps=', overlaps
  write (*, '(A,L1)') 'within_constraints=', within_constraints
  write (*, '(A,F6.1)') 'surface_area_proxy=', 12.5
  write (*, '(A)') 'status=draft_only'
  write (*, '(A,L1)') 'manufacturing_certified=', .false.
end program mesh_review
