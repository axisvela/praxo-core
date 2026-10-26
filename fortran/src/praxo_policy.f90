module praxo_policy
  use praxo_types
  implicit none
  private
  public :: path_grant, path_checker, normalize_path

  type :: path_grant
    character(:), allocatable :: root, access
  end type

  type :: path_checker
    type(path_grant), allocatable :: grants(:)
  contains
    procedure :: check => check_path
  end type
contains
  function normalize_path(path) result(normal)
    character(*), intent(in) :: path
    character(:), allocatable :: normal, text, part, prefix
    type(string_item), allocatable :: parts(:)
    integer :: i, first, count, code
    logical :: absolute, drive
    normal = ''
    if (len(path) == 0 .or. len(path) > 4096 .or. index(path, achar(0)) > 0) return
    text = path
    do i = 1, len(text)
      if (text(i:i) == achar(92)) text(i:i) = '/'
    end do
    prefix = ''
    absolute = text(1:1) == '/'
    drive = .false.
    if (len(text) >= 3) drive = text(2:3) == ':/'
    if (len(text) >= 2) then
      if (text(1:2) == '//') return
      if (text(2:2) == ':' .and. .not. drive) return
    end if
    if (drive) then
      code = iachar(text(1:1))
      if (code >= 65 .and. code <= 90) text(1:1) = achar(code + 32)
      if (text(1:1) < 'a' .or. text(1:1) > 'z') return
      prefix = text(:2)
      text = text(3:)
      absolute = .true.
    end if
    if (absolute) prefix = prefix//'/'
    allocate(parts(len(text)))
    first = 1
    count = 0
    do i = 1, len(text) + 1
      if (i <= len(text)) then
        if (text(i:i) /= '/') cycle
      end if
      part = text(first:i - 1)
      first = i + 1
      if (len(part) == 0 .or. same_string(part, '.')) cycle
      if (same_string(part, '..')) then
        if (count > 0) then
          if (.not. same_string(parts(count)%value, '..')) then
            count = count - 1
            cycle
          end if
        end if
        if (absolute) cycle
      end if
      count = count + 1
      parts(count)%value = part
    end do
    normal = prefix
    do i = 1, count
      if (i > 1) normal = normal//'/'
      normal = normal//parts(i)%value
    end do
    if (len(normal) == 0) normal = '.'
  end function

  function check_path(self, target, need, error) result(verdict)
    class(path_checker), intent(in) :: self
    character(*), intent(in) :: target, need
    type(sdk_error), intent(out) :: error
    type(decision) :: verdict
    character(:), allocatable :: root, path, access
    integer :: i
    verdict%reason = 'outside granted paths'
    if ((need /= 'read' .and. need /= 'write' .and. need /= 'readwrite') .or. len(need) /= len_trim(need)) then
      error%code = 'POLICY_ERROR'
      return
    end if
    path = normalize_path(target)
    if (len(path) == 0 .or. .not. allocated(self%grants)) return
    do i = 1, size(self%grants)
      root = normalize_path(string_value(self%grants(i)%root))
      if (len(root) == 0) cycle
      access = string_value(self%grants(i)%access)
      if (len(access) /= len_trim(access)) cycle
      if (access /= 'readwrite' .and. access /= need) cycle
      if (.not. same_string(path, root)) then
        if (same_string(root, '.')) then
          if (path == '..' .or. index(path, '../') == 1 .or. path(1:1) == '/') cycle
          if (index(path, ':') > 0) cycle
        else if (root(len(root):) == '/') then
          if (index(path, root) /= 1) cycle
        else
          if (index(path, root//'/') /= 1) cycle
        end if
      end if
      verdict%allowed = .true.
      verdict%reason = ''
      return
    end do
  end function
end module
