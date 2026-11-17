module governance_fixtures
  use praxo_types
  use praxo_interfaces
  use praxo_agent
  implicit none
  private
  public :: governor, budget_counter, scope_policy, budget_tool, fixture_model
  public :: run_child, cancel_hook, mutate_blocked, cancel_requested

  logical :: cancel_requested = .false.

  type :: budget_counter
    integer :: remaining = 0
  end type

  type :: governor
    character(:), allocatable :: allowed(:)
    character(:), allocatable :: delegable(:)
    integer :: depth = 0
    integer :: max_depth = 0
    integer :: max_children = 0
    logical :: released = .false.
    integer, pointer :: active => null()
    type(budget_counter), pointer :: budget => null()
  contains
    procedure :: delegate => delegate_child
    procedure :: release => release_child
  end type

  type, extends(policy) :: scope_policy
    type(governor), pointer :: auth => null()
  contains
    procedure :: check => check_scope
  end type

  type, extends(tool) :: budget_tool
    integer, pointer :: calls => null()
    integer, pointer :: remaining => null()
  contains
    procedure :: invoke => invoke_budget
  end type

  type, extends(model) :: fixture_model
    integer :: calls = 0
    character(:), allocatable :: tool_name, target, completion
  contains
    procedure :: generate => generate_fixture
  end type

contains
  logical function contains_name(names, name) result(found)
    character(:), allocatable, intent(in) :: names(:)
    character(*), intent(in) :: name
    integer :: i
    found = .false.
    if (.not. allocated(names)) return
    do i = 1, size(names)
      if (names(i) == name) then
        found = .true.
        return
      end if
    end do
  end function

  subroutine delegate_child(self, allowed, child, error)
    class(governor), intent(inout) :: self
    character(*), intent(in) :: allowed(:)
    type(governor), intent(out) :: child
    type(sdk_error), intent(out) :: error
    integer :: i
    error%code = ''
    if (self%depth + 1 > self%max_depth) then
      error%code = 'DELEGATION_DEPTH'
      return
    end if
    if (size(allowed) == 0) then
      error%code = 'DELEGATION_SCOPE'
      return
    end if
    do i = 1, size(allowed)
      if (.not. contains_name(self%delegable, trim(allowed(i))) .or. &
          .not. contains_name(self%allowed, trim(allowed(i)))) then
        error%code = 'DELEGATION_SCOPE'
        return
      end if
    end do
    if (.not. associated(self%active)) then
      error%code = 'DELEGATION_CHILDREN'
      return
    end if
    if (self%active >= self%max_children) then
      error%code = 'DELEGATION_CHILDREN'
      return
    end if
    if (.not. associated(self%budget)) then
      error%code = 'DELEGATION_BUDGET'
      return
    end if
    if (self%budget%remaining <= 0) then
      error%code = 'DELEGATION_BUDGET'
      return
    end if
    self%active = self%active + 1
    child%depth = self%depth + 1
    child%max_depth = self%max_depth
    child%max_children = self%max_children
    child%allowed = allowed
    if (allocated(self%delegable)) child%delegable = self%delegable
    child%active => self%active
    child%budget => self%budget
    child%released = .false.
  end subroutine

  subroutine release_child(self)
    class(governor), intent(inout) :: self
    if (self%released) return
    self%released = .true.
    if (associated(self%active)) self%active = self%active - 1
  end subroutine

  function check_scope(self, item) result(verdict)
    class(scope_policy), intent(inout) :: self
    type(action), intent(in) :: item
    type(decision) :: verdict
    verdict%allowed = .false.
    verdict%reason = 'denied by delegation scope'
    if (string_value(item%kind) == 'model.generate') then
      verdict%allowed = .true.
      verdict%reason = ''
      return
    end if
    if (string_value(item%kind) /= 'tool.invoke') return
    if (.not. associated(self%auth)) return
    if (.not. contains_name(self%auth%allowed, string_value(item%tool_name))) return
    if (index(string_value(item%arguments), 'blocked') > 0) return
    verdict%allowed = .true.
    verdict%reason = ''
  end function

  subroutine invoke_budget(self, arguments, output, error)
    class(budget_tool), intent(inout) :: self
    character(*), intent(in) :: arguments
    character(:), allocatable, intent(out) :: output
    type(sdk_error), intent(out) :: error
    error%code = ''
    if (.not. associated(self%calls) .or. .not. associated(self%remaining)) then
      error%code = 'DELEGATION_BUDGET'
      return
    end if
    if (self%remaining <= 0) then
      error%code = 'DELEGATION_BUDGET'
      return
    end if
    self%remaining = self%remaining - 1
    self%calls = self%calls + 1
    output = arguments
  end subroutine

  subroutine generate_fixture(self, req, res, error)
    class(fixture_model), intent(inout) :: self
    type(request), intent(in) :: req
    type(response), intent(out) :: res
    type(sdk_error), intent(out) :: error
    if (.false.) then
      if (size(req%messages) < 0) res%message%content = 'x'
    end if
    self%calls = self%calls + 1
    error%code = ''
    if (self%calls == 1 .and. len(string_value(self%tool_name)) > 0) then
      res%message = text_message('assistant', '')
      res%message%tool_calls = [tool_call('c1', string_value(self%tool_name), &
        '{"target":"'//string_value(self%target)//'"}')]
    else
      res%message = text_message('assistant', string_value(self%completion))
    end if
    res%usage%input_tokens = 1
    res%usage%output_tokens = 1
  end subroutine

  subroutine run_child(run_model, gate, tools, allowed_tools, use_cancel, &
      use_edit, result, error)
    type(fixture_model), target, intent(inout) :: run_model
    type(scope_policy), target, intent(inout) :: gate
    type(registry), target, intent(inout) :: tools
    character(*), intent(in) :: allowed_tools(:)
    logical, intent(in) :: use_cancel, use_edit
    type(run_result), intent(out) :: result
    type(sdk_error), intent(out) :: error
    type(agent_options) :: options
    type(session) :: state
    integer :: i
    options = agent_options()
    options%provider => run_model
    options%tools => tools
    options%gate => gate
    options%require_policy = .true.
    options%require_tool_scope = .true.
    options%max_steps = 3
    allocate(character(len=16) :: options%allowed_tools(size(allowed_tools)))
    do i = 1, size(allowed_tools)
      options%allowed_tools(i) = allowed_tools(i)
    end do
    if (use_cancel) options%cancelled => cancel_hook
    if (use_edit) then
      allocate(options%middleware(1))
      options%middleware(1)%before_tool => mutate_blocked
    end if
    state%id = 'child-session'
    allocate(state%messages(0))
    call run_agent(options, state, 'record once', 'child-run', result, error)
  end subroutine

  logical function cancel_hook(ctx)
    class(*), pointer, intent(in) :: ctx
    if (.false.) then
      if (associated(ctx)) cancel_hook = .true.
    end if
    cancel_hook = cancel_requested
  end function

  subroutine mutate_blocked(ctx, name, arguments, error)
    class(*), pointer, intent(in) :: ctx
    character(:), allocatable, intent(inout) :: name, arguments
    type(sdk_error), intent(inout) :: error
    if (.false.) then
      if (associated(ctx)) name = arguments
    end if
    arguments = '{"target":"blocked"}'
    error%code = ''
  end subroutine
end module

program governance_tests
  use praxo_types
  use praxo_interfaces, only: registry
  use governance_fixtures
  implicit none
  type(governor), target :: root, child, second_child, grandchild
  type(budget_counter), target :: budget
  type(scope_policy), target :: gate
  type(budget_tool) :: record_tool
  type(registry), target :: tools
  type(fixture_model), target :: model
  type(run_result) :: result
  type(sdk_error) :: error, delegate_error
  integer, target :: active, effects
  integer :: failures, checks
  character(16) :: scope_name(1)

  failures = 0
  checks = 0
  effects = 0
  active = 0
  budget%remaining = 2
  record_tool%spec = tool_spec('record', 'Record effects')
  record_tool%calls => effects
  record_tool%remaining => budget%remaining
  call tools%register(record_tool, error)
  call check(.not. error%failed(), 'record tool registered')

  call reset_root(root, budget, active, 1, 2, 2)
  effects = 0
  scope_name(1) = 'parent_only'
  call root%delegate(scope_name, child, delegate_error)
  call check(string_value(delegate_error%code) == 'DELEGATION_SCOPE', &
    'child tool scope cannot exceed parent delegable scope')
  call check(effects == 0 .and. budget%remaining == 2, &
    'rejected child scope leaves zero effects')

  call reset_root(root, budget, active, 1, 2, 2)
  effects = 0
  scope_name(1) = 'record'
  call root%delegate(scope_name, child, delegate_error)
  call check(.not. delegate_error%failed(), 'depth child admitted')
  call child%delegate(scope_name, grandchild, delegate_error)
  call check(string_value(delegate_error%code) == 'DELEGATION_DEPTH', &
    'grandchild rejected at max depth')
  call check(effects == 0, 'depth rejection leaves zero effects')
  call child%release()
  call check(active == 0, 'depth child release restores active count')

  call reset_root(root, budget, active, 2, 1, 2)
  effects = 0
  call root%delegate(scope_name, child, delegate_error)
  call check(.not. delegate_error%failed(), 'first child admitted')
  call root%delegate(scope_name, second_child, delegate_error)
  call check(string_value(delegate_error%code) == 'DELEGATION_CHILDREN', &
    'child limit rejects extra child')
  call child%release()
  call root%delegate(scope_name, second_child, delegate_error)
  call check(.not. delegate_error%failed(), 'child slot reusable after release')
  call second_child%release()
  call check(effects == 0 .and. active == 0, &
    'child limit checks leave zero effects')

  call reset_root(root, budget, active, 2, 2, 1)
  effects = 0
  call root%delegate(scope_name, child, delegate_error)
  call check(.not. delegate_error%failed(), 'first sibling admitted')
  call root%delegate(scope_name, second_child, delegate_error)
  call check(.not. delegate_error%failed(), 'second sibling admitted')
  gate%auth => child
  model = fixture_model()
  model%tool_name = 'record'
  model%target = 'first'
  model%completion = 'first-done'
  call run_child(model, gate, tools, scope_name, .false., .false., result, error)
  call check(.not. error%failed() .and. result%output == 'first-done', &
    'first sibling completes')
  call check(effects == 1 .and. budget%remaining == 0, &
    'first sibling consumes shared budget')
  gate%auth => second_child
  model = fixture_model()
  model%tool_name = 'record'
  model%target = 'second'
  model%completion = 'second-done'
  call run_child(model, gate, tools, scope_name, .false., .false., result, error)
  call check(string_value(error%code) == 'DELEGATION_BUDGET', &
    'second sibling fails before effect')
  call check(effects == 1, 'sibling budget leaves exactly one effect')
  call child%release()
  call second_child%release()

  call reset_root(root, budget, active, 1, 2, 1)
  effects = 0
  call root%delegate(scope_name, child, delegate_error)
  call check(.not. delegate_error%failed(), 'cancellation child admitted')
  gate%auth => child
  model = fixture_model()
  model%tool_name = 'record'
  model%target = 'safe'
  model%completion = 'unexpected'
  cancel_requested = .true.
  call run_child(model, gate, tools, scope_name, .true., .false., result, error)
  call check(string_value(error%code) == 'AGENT_CANCELLED', &
    'cancellation propagates before effect')
  call check(model%calls == 0 .and. effects == 0, &
    'cancelled child leaves zero effects')
  cancel_requested = .false.
  call child%release()

  call reset_root(root, budget, active, 1, 2, 1)
  effects = 0
  call root%delegate(scope_name, child, delegate_error)
  call check(.not. delegate_error%failed(), 'argument child admitted')
  gate%auth => child
  model = fixture_model()
  model%tool_name = 'record'
  model%target = 'safe'
  model%completion = 'unexpected'
  call run_child(model, gate, tools, scope_name, .false., .true., result, error)
  call check(string_value(error%code) == 'AGENT_POLICY_DENIED', &
    'final argument reauthorization rejects mutated value')
  call check(model%calls == 1 .and. effects == 0, &
    'reauthorization rejection leaves zero effects')
  call child%release()

  if (failures == 0) then
    print '(a,i0,a)', 'Fortran governance: ', checks, ' checks passed'
  else
    print '(a,i0,a)', 'Fortran governance: ', failures, ' failures'
    error stop 1
  end if

contains
  subroutine reset_root(node, counter, active_counter, max_depth, &
      max_children, budget_remaining)
    type(governor), intent(out) :: node
    type(budget_counter), target, intent(inout) :: counter
    integer, target, intent(inout) :: active_counter
    integer, intent(in) :: max_depth, max_children, budget_remaining
    allocate(character(len=16) :: node%allowed(2))
    node%allowed(1) = 'record'
    node%allowed(2) = 'parent_only'
    allocate(character(len=16) :: node%delegable(1))
    node%delegable(1) = 'record'
    node%depth = 0
    node%max_depth = max_depth
    node%max_children = max_children
    node%released = .false.
    node%budget => counter
    node%active => active_counter
    counter%remaining = budget_remaining
    active_counter = 0
  end subroutine

  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    failures = failures + 1
    print '(a)', 'FAIL: '//label
  end subroutine
end program
