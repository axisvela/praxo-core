module praxo_schema
  use iso_fortran_env, only: real64
  use praxo_types
  use praxo_unicode, only: unicode_length
  use praxo_json
  use praxo_pattern
  implicit none
  private
  public :: validation_error, validate_schema

  type :: validation_error
    character(:), allocatable :: path, message
  end type
contains
  subroutine validate_schema(schema, data, errors, error)
    character(*), intent(in) :: schema, data
    type(validation_error), allocatable, intent(out) :: errors(:)
    type(sdk_error), intent(out) :: error
    type(json_document) :: rules, value
    allocate(errors(0))
    call parse_json(schema, rules, error)
    if (error%failed()) return
    call parse_json(data, value, error)
    if (error%failed()) return
    call visit(1, 1, '$')
  contains
    subroutine add(path, message)
      character(*), intent(in) :: path, message
      type(validation_error), allocatable :: expanded(:)
      integer :: count
      count = size(errors)
      allocate(expanded(count + 1))
      expanded(:count) = errors
      expanded(count + 1) = validation_error(path, message)
      call move_alloc(expanded, errors)
    end subroutine

    recursive subroutine visit(rule, node, path)
      integer, intent(in) :: rule, node
      character(*), intent(in) :: path
      integer :: property, required, item, i, child, values, bound
      integer, allocatable :: entries(:), children(:)
      character(:), allocatable :: kind, name, text
      character(32) :: digits
      real(real64) :: number, limit
      logical :: ok, accepted
      type(sdk_error) :: pattern_error
      if (json_kind(rules, rule) /= 'O' .or. error%failed()) return
      kind = json_text(rules, json_get(rules, rule, 'type'))
      if (json_kind(value, node) == 'Z') then
        if (kind /= '') call add(path, 'typed value cannot be null')
        return
      end if
      select case (kind)
      case ('object')
        if (json_kind(value, node) /= 'O') then
          call add(path, 'expected object')
          return
        end if
        required = json_get(rules, rule, 'required')
        entries = json_children(rules, required)
        do i = 1, size(entries)
          name = json_text(rules, entries(i))
          if (json_get(value, node, name) == 0) call add(path//'.'//name, 'required field missing')
        end do
        property = json_get(rules, rule, 'properties')
        entries = json_children(rules, property)
        do i = 1, size(entries)
          name = rules%nodes(entries(i))%name
          child = json_get(value, node, name)
          if (child > 0) call visit(entries(i), child, path//'.'//name)
        end do
        return
      case ('array')
        if (json_kind(value, node) /= 'A') then
          call add(path, 'expected array')
          return
        end if
        item = json_get(rules, rule, 'items')
        children = json_children(value, node)
        do i = 1, size(children)
          write(digits, '(i0)') i - 1
          call visit(item, children(i), path//'['//trim(digits)//']')
        end do
        return
      case ('string')
        if (json_kind(value, node) /= 'S') then
          call add(path, 'expected string')
          return
        end if
        text = json_text(value, node)
        limit = json_real(rules, json_get(rules, rule, 'minLength'), ok)
        if (ok .and. limit > 0) then
          if (unicode_length(text) < limit) call add(path, 'below minimum string length')
        end if
        limit = json_real(rules, json_get(rules, rule, 'maxLength'), ok)
        if (ok .and. limit > 0) then
          if (unicode_length(text) > limit) call add(path, 'above maximum string length')
        end if
        bound = json_get(rules, rule, 'pattern')
        if (json_kind(rules, bound) == 'S') then
          accepted = match_pattern(json_text(rules, bound), text, pattern_error)
          if (pattern_error%failed()) then
            error = pattern_error
            return
          end if
          if (.not. accepted) call add(path, 'pattern not matched')
        end if
      case ('number', 'integer')
        number = json_real(value, node, ok)
        if (.not. ok) then
          call add(path, 'expected representable number')
          return
        end if
        if (kind == 'integer' .and. abs(number - aint(number)) > 0) then
          call add(path, 'expected integer')
          return
        end if
        limit = json_real(rules, json_get(rules, rule, 'minimum'), ok)
        if (ok .and. abs(limit) > 0) then
          if (number < limit) call add(path, 'below minimum')
        end if
        limit = json_real(rules, json_get(rules, rule, 'maximum'), ok)
        if (ok .and. abs(limit) > 0) then
          if (number > limit) call add(path, 'above maximum')
        end if
      case ('boolean')
        if (json_kind(value, node) /= 'T' .and. json_kind(value, node) /= 'F') then
          call add(path, 'expected boolean')
          return
        end if
      case default
        return
      end select
      values = json_get(rules, rule, 'enum')
      if (json_kind(rules, values) /= 'A') return
      entries = json_children(rules, values)
      do i = 1, size(entries)
        if (json_equal(rules, entries(i), value, node)) return
      end do
      call add(path, 'value not in enum')
    end subroutine
  end subroutine
end module
