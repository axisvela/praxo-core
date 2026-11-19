module praxo_interfaces
  use praxo_types
  implicit none
  private
  public :: model, tool, policy, event_sink, registry, delta_interface, delta_handler
  public :: run_model

  type :: delta_handler
    procedure(delta_interface), pointer, nopass :: callback => null()
    class(*), pointer :: ctx => null()
  end type

  type, abstract :: model
  contains
    procedure(generate_interface), deferred :: generate
    procedure :: generate_stream => default_generate_stream
  end type

  type, abstract :: tool
    type(tool_spec) :: spec
  contains
    procedure(invoke_interface), deferred :: invoke
  end type

  type, abstract :: policy
  contains
    procedure(check_interface), deferred :: check
  end type

  type, abstract :: event_sink
  contains
    procedure(emit_interface), deferred :: emit
  end type

  type :: tool_entry
    class(tool), allocatable :: value
  end type

  type :: registry
    private
    type(tool_entry), allocatable :: entries(:)
  contains
    procedure :: register => register_tool
    procedure :: invoke => invoke_registered
    procedure :: specs => registry_specs
    procedure :: has => registry_has
  end type

  abstract interface
    subroutine delta_interface(ctx, delta, error)
      import :: sdk_error
      class(*), pointer, intent(in) :: ctx
      character(*), intent(in) :: delta
      type(sdk_error), intent(inout) :: error
    end subroutine
    subroutine generate_interface(self, req, res, error)
      import model, request, response, sdk_error
      class(model), intent(inout) :: self
      type(request), intent(in) :: req
      type(response), intent(out) :: res
      type(sdk_error), intent(out) :: error
    end subroutine
    subroutine generate_stream_interface(self, req, on_delta, ctx, res, error)
      import model, request, response, sdk_error, delta_interface
      class(model), intent(inout) :: self
      type(request), intent(in) :: req
      procedure(delta_interface) :: on_delta
      class(*), pointer, intent(in) :: ctx
      type(response), intent(out) :: res
      type(sdk_error), intent(out) :: error
    end subroutine
    subroutine invoke_interface(self, arguments, output, error)
      import tool, sdk_error
      class(tool), intent(inout) :: self
      character(*), intent(in) :: arguments
      character(:), allocatable, intent(out) :: output
      type(sdk_error), intent(out) :: error
    end subroutine
    function check_interface(self, item) result(result)
      import policy, action, decision
      class(policy), intent(inout) :: self
      type(action), intent(in) :: item
      type(decision) :: result
    end function
    subroutine emit_interface(self, item)
      import event_sink, event
      class(event_sink), intent(inout) :: self
      type(event), intent(in) :: item
    end subroutine
  end interface
contains
  subroutine run_model(provider, delta, req, res, error)
    class(model), pointer, intent(in) :: provider
    class(model), pointer :: active
    type(delta_handler), intent(in) :: delta
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    active => provider
    if (associated(delta%callback)) then
      call active%generate_stream(req, delta%callback, delta%ctx, res, error)
    else
      call active%generate(req, res, error)
    end if
  end subroutine

  subroutine default_generate_stream(self, req, on_delta, ctx, res, error)
    class(model), intent(inout) :: self
    type(request), intent(in) :: req
    procedure(delta_interface) :: on_delta
    class(*), pointer, intent(in) :: ctx
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    type(sdk_error) :: delta_error
    call self%generate(req, res, error)
    if (error%failed()) return
    if (len(res%message%content) == 0) return
    delta_error%code = ''
    call on_delta(ctx, res%message%content, delta_error)
    if (delta_error%failed()) error = delta_error
  end subroutine

  logical function registry_has(self, name) result(found)
    class(registry), intent(in) :: self
    character(*), intent(in) :: name
    integer :: i
    found = .false.
    if (.not. allocated(self%entries)) return
    do i = 1, size(self%entries)
      if (.not. same_string(self%entries(i)%value%spec%name, name)) cycle
      found = .true.
      return
    end do
  end function

  subroutine register_tool(self, item, error)
    class(registry), intent(inout) :: self
    class(tool), intent(in) :: item
    type(sdk_error), intent(out) :: error
    type(tool_entry), allocatable :: expanded(:)
    integer :: i, count
    if (len_trim(string_value(item%spec%name)) == 0) then
      error%code = 'INVALID_REQUEST'
      return
    end if
    count = 0
    if (allocated(self%entries)) count = size(self%entries)
    do i = 1, count
      if (same_string(self%entries(i)%value%spec%name, item%spec%name)) then
        deallocate(self%entries(i)%value)
        allocate(self%entries(i)%value, source=item)
        return
      end if
    end do
    allocate(expanded(count + 1))
    if (count > 0) expanded(:count) = self%entries
    allocate(expanded(count + 1)%value, source=item)
    call move_alloc(expanded, self%entries)
  end subroutine

  subroutine invoke_registered(self, name, arguments, output, error)
    class(registry), intent(inout) :: self
    character(*), intent(in) :: name, arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    integer :: i
    if (allocated(self%entries)) then
      do i = 1, size(self%entries)
        if (.not. same_string(self%entries(i)%value%spec%name, name)) cycle
        call self%entries(i)%value%invoke(arguments, output, error)
        return
      end do
    end if
    error%code = 'TOOL_NOT_FOUND'
  end subroutine

  function registry_specs(self) result(specs)
    class(registry), intent(in) :: self
    type(tool_spec), allocatable :: specs(:)
    type(tool_spec) :: temporary
    integer :: i, j, count
    count = 0
    if (allocated(self%entries)) count = size(self%entries)
    allocate(specs(count))
    do i = 1, count
      specs(i) = self%entries(i)%value%spec
    end do
    do i = 2, count
      j = i
      do while (j > 1)
        if (specs(j - 1)%name <= specs(j)%name) exit
        temporary = specs(j - 1)
        specs(j - 1) = specs(j)
        specs(j) = temporary
        j = j - 1
      end do
    end do
  end function
end module
