program authentication_test
  use iso_fortran_env, only: int64
  use praxo_types, only: sdk_error
  use service_authentication
  implicit none

  integer(int64), parameter :: now = 1700000000_int64
  character(*), parameter :: endpoint = 'https://id.example.com/introspect'
  character(*), parameter :: active_body = &
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000060}'

  integer :: checks = 0
  integer :: fake_status = 200
  integer :: fake_calls = 0
  logical :: fake_failed = .false.
  character(:), allocatable :: fake_body, fake_last_url
  character(:), allocatable :: fake_last_form, fake_last_auth
  type(introspection_authenticator) :: intro
  type(revocation_client) :: revoker
  type(service_principal) :: principal
  type(sdk_error) :: error
  integer :: before_calls

  call reset_fake(200, active_body, .false.)
  call init_introspection(intro, fake_transport, endpoint, 'svc', 'secret', &
    'tenant')
  call check(authenticate(intro, 'Bearer opaque-token', now, principal), &
    'active token accepted')
  call check(principal%subject == 'user-1', 'subject')
  call check(principal%tenant == 'tenant-a', 'tenant')
  call check(principal%expires == now + 60_int64, 'expires')
  call check(principal%valid, 'principal valid')
  call check(fake_calls == 1, 'one introspection call')
  call check(fake_last_url == endpoint, 'endpoint')
  call check(index(fake_last_form, 'token=opaque-token') > 0, 'token field')
  call check(index(fake_last_form, 'client_id=svc') > 0, 'client id field')
  call check(index(fake_last_form, 'client_secret=secret') > 0, &
    'client secret field')
  call check(fake_last_auth == 'Basic c3ZjOnNlY3JldA==', &
    'basic authorization')

  call reset_fake(200, active_body, .false.)
  call init_introspection(intro, fake_transport, endpoint, 'svc', 'secret', &
    'tenant')
  before_calls = fake_calls
  call check(.not. authenticate(intro, '', now, principal), &
    'missing authorization')
  call check(.not. authenticate(intro, 'Basic opaque-token', now, principal), &
    'wrong scheme')
  call check(.not. authenticate(intro, 'Bearer', now, principal), &
    'missing token')
  call check(.not. authenticate(intro, 'Bearer   ', now, principal), &
    'empty token')
  call check(fake_calls == before_calls, 'local rejection avoids transport')

  call expect_rejected('inactive token', 'Bearer token-1', &
    '{"active":false,"sub":"user-1","tenant":"tenant-a","exp":1700000060}', &
    200)
  call expect_rejected('missing sub', 'Bearer token-1', &
    '{"active":true,"tenant":"tenant-a","exp":1700000060}', 200)
  call expect_rejected('empty sub', 'Bearer token-1', &
    '{"active":true,"sub":"","tenant":"tenant-a","exp":1700000060}', 200)
  call expect_rejected('missing tenant', 'Bearer token-1', &
    '{"active":true,"sub":"user-1","exp":1700000060}', 200)
  call expect_rejected('empty tenant', 'Bearer token-1', &
    '{"active":true,"sub":"user-1","tenant":"","exp":1700000060}', 200)
  call expect_rejected('expired token', 'Bearer token-1', &
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000000}', &
    200)
  call expect_rejected('missing expiration', 'Bearer token-1', &
    '{"active":true,"sub":"user-1","tenant":"tenant-a"}', 200)
  call expect_rejected('fractional expiration', 'Bearer token-1', &
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000060.5}', &
    200)
  call expect_rejected('malformed json', 'Bearer token-1', 'not-json', 200)
  call expect_rejected('non-200', 'Bearer token-1', active_body, 500)

  call reset_fake(200, active_body, .true.)
  call init_introspection(intro, fake_transport, endpoint, '', '', 'tenant')
  call check(.not. authenticate(intro, 'Bearer token-1', now, principal), &
    'transport error')

  call reset_fake(200, &
    '{"active":true,"sub":"user-1","org":"org-a","exp":1700000060}', .false.)
  call init_introspection(intro, fake_transport, endpoint, '', '', 'org')
  call check(authenticate(intro, 'Bearer token-1', now, principal), &
    'custom tenant claim accepted')
  call check(principal%tenant == 'org-a', 'custom tenant value')
  call check(fake_last_auth == '', 'no basic authorization without client id')

  call reset_fake(200, '', .false.)
  call init_revocation(revoker, fake_transport, &
    'https://id.example.com/revoke', 'svc', 'secret')
  call revoke(revoker, 'token-1', error)
  call check(.not. error%failed(), 'revocation success')
  call check(fake_calls == 1, 'one revocation call')
  call check(index(fake_last_form, 'token=token-1') > 0, &
    'revocation token field')
  call check(index(fake_last_form, 'token_type_hint=access_token') > 0, &
    'revocation hint field')
  call check(fake_last_auth == 'Basic c3ZjOnNlY3JldA==', &
    'revocation basic authorization')

  call reset_fake(400, '', .false.)
  call init_revocation(revoker, fake_transport, &
    'https://id.example.com/revoke', '', '')
  call revoke(revoker, 'token-1', error)
  call check(error%failed() .and. error%code == 'AUTH_REVOCATION_FAILED', &
    'revocation non-200')

  call reset_fake(200, '', .true.)
  call init_revocation(revoker, fake_transport, &
    'https://id.example.com/revoke', '', '')
  call revoke(revoker, 'token-1', error)
  call check(error%failed() .and. error%code == 'AUTH_REVOCATION_FAILED', &
    'revocation transport error')

  call reset_fake(200, '', .false.)
  call init_revocation(revoker, fake_transport, &
    'https://id.example.com/revoke', '', '')
  before_calls = fake_calls
  call revoke(revoker, '', error)
  call check(error%failed() .and. &
    error%code == 'AUTH_REVOCATION_TOKEN_REQUIRED', 'empty revocation token')
  call check(fake_calls == before_calls, 'empty revocation avoids transport')

  print '(a)', 'Fortran service auth tests passed'
contains
  subroutine reset_fake(status, body, failed)
    integer, intent(in) :: status
    character(*), intent(in) :: body
    logical, intent(in) :: failed
    fake_status = status
    fake_body = body
    fake_failed = failed
    fake_calls = 0
    fake_last_url = ''
    fake_last_form = ''
    fake_last_auth = ''
  end subroutine

  function fake_transport(url, form, authorization) result(response)
    character(*), intent(in) :: url, form, authorization
    type(transport_result) :: response
    fake_calls = fake_calls + 1
    fake_last_url = url
    fake_last_form = form
    fake_last_auth = authorization
    response%status = fake_status
    response%body = fake_body
    response%failed = fake_failed
  end function

  subroutine expect_rejected(label, authorization, body, status)
    character(*), intent(in) :: label, authorization, body
    integer, intent(in) :: status
    type(introspection_authenticator) :: local_auth
    type(service_principal) :: local_principal
    call reset_fake(status, body, .false.)
    call init_introspection(local_auth, fake_transport, endpoint, '', '', &
      'tenant')
    call check(.not. authenticate(local_auth, authorization, now, &
      local_principal), label)
  end subroutine

  subroutine check(condition, label)
    logical, intent(in) :: condition
    character(*), intent(in) :: label
    checks = checks + 1
    if (condition) return
    print '(a)', 'FAIL: '//label
    error stop 1
  end subroutine
end program
