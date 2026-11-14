program identity_policy_example
  use praxo_types
  implicit none
  type(action) :: item
  type(decision) :: verdict

  item%kind = 'model.generate'
  verdict = authorize(item, 'acme', 'operator', .true.)
  if (.not. verdict%allowed) stop 1

  item%kind = 'tool.invoke'
  item%tool_name = 'record'
  item%arguments = '{"tenant":"acme"}'
  verdict = authorize(item, 'acme', 'operator', .true.)
  if (.not. verdict%allowed) stop 1

  verdict = authorize(item, 'acme', 'viewer', .true.)
  if (verdict%allowed) stop 1
  verdict = authorize(item, 'acme', 'operator', .false.)
  if (verdict%allowed) stop 1
  verdict = authorize(item, 'other', 'operator', .true.)
  if (verdict%allowed) stop 1

  print '(a)', 'Fortran identity policy example passed'
contains
  function authorize(item, tenant, role, active) result(result)
    type(action), intent(in) :: item
    character(*), intent(in) :: tenant, role
    logical, intent(in) :: active
    type(decision) :: result
    result%allowed = .false.
    result%reason = 'denied'
    if (.not. active) return
    if (item%kind == 'model.generate') then
      result%allowed = .true.
      return
    end if
    if (role /= 'operator') return
    if (item%tool_name /= 'record') return
    if (index(item%arguments, '"tenant":"'//tenant//'"') == 0) return
    result%allowed = .true.
  end function
end program
