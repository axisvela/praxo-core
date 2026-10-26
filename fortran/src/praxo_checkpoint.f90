module praxo_checkpoint
  use praxo_types
  use praxo_unicode, only: quote_json
  use praxo_json
  implicit none
  private
  public :: checkpoint_allowlist

  type :: checkpoint_allowlist
    private
    type(string_item), allocatable :: names(:)
  contains
    procedure :: register => register_type
    procedure :: marshal
    procedure :: unmarshal
    procedure, private :: allowed
  end type
contains
  subroutine register_type(self, name, error)
    class(checkpoint_allowlist), intent(inout) :: self
    character(*), intent(in) :: name
    type(sdk_error), intent(out) :: error
    type(string_item), allocatable :: expanded(:)
    integer :: count
    if (len(name) == 0) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    if (self%allowed(name)) return
    count = 0
    if (allocated(self%names)) count = size(self%names)
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = self%names
    expanded(count + 1)%value = name
    call move_alloc(expanded, self%names)
  end subroutine

  logical function allowed(self, name)
    class(checkpoint_allowlist), intent(in) :: self
    character(*), intent(in) :: name
    integer :: i
    allowed = .false.
    if (.not. allocated(self%names)) return
    do i = 1, size(self%names)
      if (len(self%names(i)%value) /= len(name)) cycle
      if (self%names(i)%value /= name) cycle
      allowed = .true.
      return
    end do
  end function

  function marshal(self, name, value, error) result(envelope)
    class(checkpoint_allowlist), intent(in) :: self
    character(*), intent(in) :: name, value
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: envelope, key, data
    type(json_document) :: doc
    envelope = ''
    if (.not. self%allowed(name)) then
      error%code = 'CHECKPOINT_TYPE_NOT_ALLOWED'
      return
    end if
    call parse_json(value, doc, error)
    if (error%failed()) return
    data = encode_json(doc, 1, error)
    if (error%failed()) return
    key = quote_json(name, error)
    if (.not. error%failed()) envelope = '{"type":'//key//',"data":'//data//'}'
    if (len(envelope) > 262144) then
      envelope = ''
      error%code = 'JSON_CAPACITY'
    end if
  end function

  function unmarshal(self, envelope, error) result(value)
    class(checkpoint_allowlist), intent(in) :: self
    character(*), intent(in) :: envelope
    type(sdk_error), intent(out) :: error
    character(:), allocatable :: value
    type(json_document) :: doc
    integer :: node, data
    value = ''
    call parse_json(envelope, doc, error)
    if (error%failed()) return
    node = json_get(doc, 1, 'type')
    if (json_kind(doc, node) /= 'S') then
      error%code = 'CHECKPOINT_TYPE_NOT_ALLOWED'
      return
    end if
    if (.not. self%allowed(json_text(doc, node))) then
      error%code = 'CHECKPOINT_TYPE_NOT_ALLOWED'
      return
    end if
    data = json_get(doc, 1, 'data')
    value = encode_json(doc, data, error)
  end function
end module
