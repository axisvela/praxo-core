module praxo_plugin_process
  use iso_c_binding
  implicit none
  private
  public :: plugin_process_host, plugin_process_start, plugin_process_invoke
  public :: plugin_process_stop

  type :: plugin_process_host
    type(c_ptr) :: handle = c_null_ptr
  end type

  type, bind(c) :: c_config
    type(c_ptr) :: plugin_id
    type(c_ptr) :: path
    type(c_ptr) :: args
    integer(c_int) :: arg_count
    type(c_ptr) :: token
    integer(c_int) :: start_timeout_ms
    integer(c_int) :: invoke_timeout_ms
  end type

  interface
    function c_start(config, err) bind(c, name="px_plugin_process_start") result(handle)
      import :: c_ptr, c_config
      type(c_config), intent(in) :: config
      type(c_ptr), intent(inout) :: err
      type(c_ptr) :: handle
    end function

    subroutine c_invoke(handle, service, method, payload, payload_length, &
        response, response_length, err) bind(c, name="px_plugin_process_invoke")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: handle, service, method, payload
      integer(c_size_t), value :: payload_length
      type(c_ptr), intent(inout) :: response
      integer(c_size_t), intent(inout) :: response_length
      type(c_ptr), intent(inout) :: err
    end subroutine

    subroutine c_stop(handle) bind(c, name="px_plugin_process_stop")
      import :: c_ptr
      type(c_ptr), value :: handle
    end subroutine

    subroutine c_free(pointer) bind(c, name="free")
      import :: c_ptr
      type(c_ptr), value :: pointer
    end subroutine
  end interface
contains
  subroutine plugin_process_start(host, plugin_id, path, args, token, status, error)
    type(plugin_process_host), intent(out) :: host
    character(*), intent(in) :: plugin_id, path
    character(*), intent(in) :: args(:)
    character(*), intent(in), optional :: token
    integer, intent(out) :: status
    character(:), allocatable, intent(out) :: error
    type(c_config) :: config
    character(kind=c_char), allocatable, target :: id_data(:)
    character(kind=c_char), allocatable, target :: path_data(:)
    character(kind=c_char), allocatable, target :: token_data(:)
    character(kind=c_char), allocatable, target :: arg_data(:, :)
    type(c_ptr), allocatable, target :: argv(:)
    type(c_ptr) :: err
    integer :: index, position, max_length

    id_data = c_string(plugin_id)
    path_data = c_string(path)
    config%plugin_id = c_loc(id_data(1))
    config%path = c_loc(path_data(1))
    config%arg_count = int(size(args), c_int)
    config%start_timeout_ms = 10000_c_int
    config%invoke_timeout_ms = 30000_c_int
    if (present(token)) then
      token_data = c_string(token)
      config%token = c_loc(token_data(1))
    else
      config%token = c_null_ptr
    end if
    max_length = 1
    do index = 1, size(args)
      max_length = max(max_length, len_trim(args(index)) + 1)
    end do
    allocate(arg_data(max_length, size(args)))
    allocate(argv(size(args)))
    do index = 1, size(args)
      arg_data(:, index) = c_null_char
      do position = 1, len_trim(args(index))
        arg_data(position, index) = args(index)(position:position)
      end do
      argv(index) = c_loc(arg_data(1, index))
    end do
    config%args = c_null_ptr
    if (size(args) > 0) config%args = c_loc(argv(1))
    err = c_null_ptr
    host%handle = c_start(config, err)
    error = from_c(err)
    status = merge(0, 1, c_associated(host%handle))
    deallocate(id_data, path_data, arg_data, argv)
    if (allocated(token_data)) deallocate(token_data)
  end subroutine

  subroutine plugin_process_invoke(host, service, method, payload, response, status, error)
    type(plugin_process_host), intent(in) :: host
    character(*), intent(in) :: service, method, payload
    character(:), allocatable, intent(out) :: response
    integer, intent(out) :: status
    character(:), allocatable, intent(out) :: error
    character(kind=c_char), allocatable, target :: service_data(:)
    character(kind=c_char), allocatable, target :: method_data(:)
    character(kind=c_char), allocatable, target :: payload_data(:)
    type(c_ptr) :: response_pointer, err
    integer(c_size_t) :: response_length
    integer :: position

    service_data = c_string(service)
    method_data = c_string(method)
    payload_data = c_string(payload)
    response_pointer = c_null_ptr
    err = c_null_ptr
    response_length = 0_c_size_t
    call c_invoke(host%handle, c_loc(service_data(1)), c_loc(method_data(1)), &
      c_loc(payload_data(1)), int(len(payload), c_size_t), response_pointer, &
      response_length, err)
    error = from_c(err)
    if (.not. c_associated(response_pointer)) then
      response = ''
      status = 1
    else
      block
        character(kind=c_char), pointer :: chars(:)
        call c_f_pointer(response_pointer, chars, [int(response_length)])
        allocate(character(int(response_length)) :: response)
        do position = 1, int(response_length)
          response(position:position) = chars(position)
        end do
      end block
      call c_free(response_pointer)
      status = 0
    end if
    deallocate(service_data, method_data, payload_data)
  end subroutine

  subroutine plugin_process_stop(host)
    type(plugin_process_host), intent(inout) :: host
    if (c_associated(host%handle)) then
      call c_stop(host%handle)
      host%handle = c_null_ptr
    end if
  end subroutine

  function c_string(value) result(output)
    character(*), intent(in) :: value
    character(kind=c_char), allocatable :: output(:)
    integer :: index
    allocate(output(len(value) + 1))
    do index = 1, len(value)
      output(index) = value(index:index)
    end do
    output(len(value) + 1) = c_null_char
  end function

  function from_c(pointer) result(output)
    type(c_ptr), intent(in) :: pointer
    character(:), allocatable :: output
    character(kind=c_char), pointer :: chars(:)
    integer :: length, index
    if (.not. c_associated(pointer)) then
      output = ''
      return
    end if
    call c_f_pointer(pointer, chars, [4096])
    length = 0
    do
      if (chars(length + 1) == c_null_char) exit
      length = length + 1
      if (length >= 4095) exit
    end do
    allocate(character(length) :: output)
    do index = 1, length
      output(index:index) = chars(index)
    end do
  end function
end module
