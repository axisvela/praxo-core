module service_authentication
  use iso_fortran_env, only: int64
  use praxo_json
  use praxo_types, only: sdk_error
  implicit none
  private

  public :: service_principal, transport_result, transport_iface
  public :: introspection_authenticator, revocation_client
  public :: init_introspection, authenticate
  public :: init_revocation, revoke

  type :: service_principal
    character(:), allocatable :: subject
    character(:), allocatable :: tenant
    integer(int64) :: expires = 0
    logical :: valid = .false.
  end type

  type :: transport_result
    integer :: status = 0
    character(:), allocatable :: body
    logical :: failed = .false.
  end type

  abstract interface
    function transport_iface(url, form, authorization) result(response)
      import :: transport_result
      character(*), intent(in) :: url
      character(*), intent(in) :: form
      character(*), intent(in) :: authorization
      type(transport_result) :: response
    end function
  end interface

  type :: introspection_authenticator
    procedure(transport_iface), pointer, nopass :: transport => null()
    character(:), allocatable :: endpoint
    character(:), allocatable :: client_id
    character(:), allocatable :: client_secret
    character(:), allocatable :: tenant_claim
  end type

  type :: revocation_client
    procedure(transport_iface), pointer, nopass :: transport => null()
    character(:), allocatable :: endpoint
    character(:), allocatable :: client_id
    character(:), allocatable :: client_secret
  end type

contains
  subroutine init_introspection(auth, transport, endpoint, client_id, &
      client_secret, tenant_claim)
    type(introspection_authenticator), intent(out) :: auth
    procedure(transport_iface) :: transport
    character(*), intent(in) :: endpoint
    character(*), intent(in) :: client_id
    character(*), intent(in) :: client_secret
    character(*), intent(in) :: tenant_claim
    auth%transport => transport
    auth%endpoint = endpoint
    auth%client_id = client_id
    auth%client_secret = client_secret
    if (len_trim(tenant_claim) == 0) then
      auth%tenant_claim = 'tenant'
    else
      auth%tenant_claim = trim(tenant_claim)
    end if
  end subroutine

  logical function authenticate(auth, authorization, now, principal) result(ok)
    type(introspection_authenticator), intent(in) :: auth
    character(*), intent(in) :: authorization
    integer(int64), intent(in) :: now
    type(service_principal), intent(out) :: principal
    type(transport_result) :: response
    type(json_document) :: doc
    type(sdk_error) :: error
    character(:), allocatable :: token, form, header, subject, tenant, text
    integer :: active_node, subject_node, tenant_node, expires_node, status
    integer(int64) :: expires
    ok = .false.
    principal%subject = ''
    principal%tenant = ''
    principal%expires = 0
    principal%valid = .false.
    if (len(authorization) <= 7) return
    if (authorization(1:7) /= 'Bearer ') return
    token = trim(adjustl(authorization(8:)))
    if (len(token) == 0) return
    if (.not. associated(auth%transport)) return
    form = 'token='//url_encode(token)//'&client_id='// &
      url_encode(auth%client_id)//'&client_secret='// &
      url_encode(auth%client_secret)
    header = basic_authorization(auth%client_id, auth%client_secret)
    response = auth%transport(auth%endpoint, form, header)
    if (response%failed) return
    if (response%status /= 200) return
    call parse_json(response%body, doc, error)
    if (error%failed()) return
    if (json_kind(doc, 1) /= 'O') return
    active_node = json_get(doc, 1, 'active')
    if (json_kind(doc, active_node) /= 'T') return
    subject_node = json_get(doc, 1, 'sub')
    if (json_kind(doc, subject_node) /= 'S') return
    subject = json_text(doc, subject_node)
    if (len(subject) == 0) return
    tenant_node = json_get(doc, 1, trim(auth%tenant_claim))
    if (json_kind(doc, tenant_node) /= 'S') return
    tenant = json_text(doc, tenant_node)
    if (len(tenant) == 0) return
    expires_node = json_get(doc, 1, 'exp')
    if (json_kind(doc, expires_node) /= 'N') return
    text = json_text(doc, expires_node)
    if (index(text, '.') > 0 .or. index(text, 'e') > 0 .or. &
        index(text, 'E') > 0) return
    read(text, *, iostat=status) expires
    if (status /= 0) return
    if (expires <= now) return
    principal%subject = subject
    principal%tenant = tenant
    principal%expires = expires
    principal%valid = .true.
    ok = .true.
  end function

  subroutine init_revocation(client, transport, endpoint, client_id, &
      client_secret)
    type(revocation_client), intent(out) :: client
    procedure(transport_iface) :: transport
    character(*), intent(in) :: endpoint
    character(*), intent(in) :: client_id
    character(*), intent(in) :: client_secret
    client%transport => transport
    client%endpoint = endpoint
    client%client_id = client_id
    client%client_secret = client_secret
  end subroutine

  subroutine revoke(client, token, error)
    type(revocation_client), intent(in) :: client
    character(*), intent(in) :: token
    type(sdk_error), intent(out) :: error
    type(transport_result) :: response
    character(:), allocatable :: form, header
    error%code = ''
    if (len_trim(token) == 0) then
      error%code = 'AUTH_REVOCATION_TOKEN_REQUIRED'
      return
    end if
    if (.not. associated(client%transport)) then
      error%code = 'AUTH_REVOCATION_FAILED'
      return
    end if
    form = 'token='//url_encode(trim(token))// &
      '&token_type_hint=access_token&client_id='// &
      url_encode(client%client_id)//'&client_secret='// &
      url_encode(client%client_secret)
    header = basic_authorization(client%client_id, client%client_secret)
    response = client%transport(client%endpoint, form, header)
    if (response%failed) then
      error%code = 'AUTH_REVOCATION_FAILED'
      return
    end if
    if (response%status /= 200) error%code = 'AUTH_REVOCATION_FAILED'
  end subroutine

  function basic_authorization(client_id, client_secret) result(header)
    character(*), intent(in) :: client_id
    character(*), intent(in) :: client_secret
    character(:), allocatable :: header
    if (len(client_id) == 0) then
      header = ''
    else
      header = 'Basic '//base64_encode(client_id//':'//client_secret)
    end if
  end function

  function url_encode(value) result(encoded)
    character(*), intent(in) :: value
    character(:), allocatable :: encoded
    character(*), parameter :: hex = '0123456789ABCDEF'
    integer :: i, b
    encoded = ''
    do i = 1, len(value)
      b = iachar(value(i:i))
      if (((b >= 65) .and. (b <= 90)) .or. ((b >= 97) .and. (b <= 122)) &
          .or. ((b >= 48) .and. (b <= 57)) .or. b == 45 .or. b == 46 &
          .or. b == 95 .or. b == 126) then
        encoded = encoded//value(i:i)
      else
        encoded = encoded//'%'//hex(b/16 + 1:b/16 + 1)// &
          hex(iand(b, 15) + 1:iand(b, 15) + 1)
      end if
    end do
  end function

  function base64_encode(value) result(encoded)
    character(*), intent(in) :: value
    character(:), allocatable :: encoded
    character(*), parameter :: alphabet = &
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    integer :: i, n, b1, b2, b3
    encoded = ''
    n = len(value)
    i = 1
    do while (i <= n)
      b1 = iachar(value(i:i))
      b2 = 0
      b3 = 0
      if (i + 1 <= n) b2 = iachar(value(i + 1:i + 1))
      if (i + 2 <= n) b3 = iachar(value(i + 2:i + 2))
      encoded = encoded//alphabet(b1/4 + 1:b1/4 + 1)
      encoded = encoded//alphabet(iand(b1, 3)*16 + b2/16 + 1: &
        iand(b1, 3)*16 + b2/16 + 1)
      if (i + 1 <= n) then
        encoded = encoded//alphabet(iand(b2, 15)*4 + b3/64 + 1: &
          iand(b2, 15)*4 + b3/64 + 1)
      else
        encoded = encoded//'='
      end if
      if (i + 2 <= n) then
        encoded = encoded//alphabet(iand(b3, 63) + 1:iand(b3, 63) + 1)
      else
        encoded = encoded//'='
      end if
      i = i + 3
    end do
  end function
end module
