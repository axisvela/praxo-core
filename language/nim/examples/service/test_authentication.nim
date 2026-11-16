import std/base64
import std/json
import std/options
import std/tables

import ./authentication

type
  ScriptedTransport = ref object
    status: int
    body: string
    unavailable: bool
    forms: seq[Table[string, string]]
    authorizations: seq[Option[string]]

proc post(
  transport: ScriptedTransport,
  url: string,
  form: Table[string, string],
  authorization: Option[string],
): (int, string) =
  transport.forms.add(form)
  transport.authorizations.add(authorization)
  if transport.unavailable:
    raise newException(AuthError, "identity provider unavailable")
  return (transport.status, transport.body)

proc scripted(status: int, body: string): ScriptedTransport =
  return ScriptedTransport(
    status: status,
    body: body,
    unavailable: false,
    forms: @[],
    authorizations: @[],
  )

proc authenticatorFor(
  transport: ScriptedTransport,
  tenantClaim: string = "tenant",
  clientId: string = "",
  clientSecret: string = "",
): IntrospectionAuthenticator =
  return newIntrospectionAuthenticator(
    proc (
      url: string,
      form: Table[string, string],
      authorization: Option[string],
    ): (int, string) =
      post(transport, url, form, authorization),
    "https://id.example.com/introspect",
    clientId,
    clientSecret,
    tenantClaim,
  )

proc revokerFor(transport: ScriptedTransport): RevocationClient =
  return newRevocationClient(
    proc (
      url: string,
      form: Table[string, string],
      authorization: Option[string],
    ): (int, string) =
      post(transport, url, form, authorization),
    "https://id.example.com/revoke",
    "client",
    "secret",
  )

let now = 1_700_000_000

let active = scripted(
  200,
  $(%*{"active": true, "sub": "user-1", "tenant": "local", "exp": now + 60}),
)
let authenticator = authenticatorFor(
  active, clientId = "client", clientSecret = "secret",
)
let principal = authenticate(authenticator, "Bearer opaque-token", now)
doAssert principal.isSome
doAssert principal.get().subject == "user-1"
doAssert principal.get().tenant == "local"
doAssert principal.get().expires == now + 60
doAssert active.forms[^1]["token"] == "opaque-token"
doAssert active.forms[^1]["client_id"] == "client"
doAssert active.forms[^1]["client_secret"] == "secret"
doAssert active.authorizations[^1] == some("Basic " & base64.encode("client:secret"))

let blankClient = scripted(
  200,
  $(%*{"active": true, "sub": "user-1", "tenant": "local", "exp": now + 60}),
)
doAssert authenticate(
  authenticatorFor(blankClient), "Bearer opaque-token", now,
).isSome
doAssert blankClient.authorizations[^1].isNone

doAssert authenticate(authenticator, "", now).isNone
doAssert authenticate(authenticator, "Basic abc", now).isNone
doAssert authenticate(authenticator, "bearer token", now).isNone
doAssert authenticate(authenticator, "Token abc", now).isNone
doAssert authenticate(authenticator, "Bearer ", now).isNone
doAssert authenticate(authenticator, "Bearer    ", now).isNone

let inactive = scripted(200, $(%*{"active": false}))
doAssert authenticate(
  authenticatorFor(inactive), "Bearer opaque-token", now,
).isNone

let noSub = scripted(
  200, $(%*{"active": true, "tenant": "local", "exp": now + 60}),
)
doAssert authenticate(authenticatorFor(noSub), "Bearer opaque-token", now).isNone

let emptySub = scripted(
  200, $(%*{"active": true, "sub": "", "tenant": "local", "exp": now + 60}),
)
doAssert authenticate(authenticatorFor(emptySub), "Bearer opaque-token", now).isNone

let noTenant = scripted(
  200, $(%*{"active": true, "sub": "user-1", "exp": now + 60}),
)
doAssert authenticate(authenticatorFor(noTenant), "Bearer opaque-token", now).isNone

let emptyTenant = scripted(
  200, $(%*{"active": true, "sub": "user-1", "tenant": "", "exp": now + 60}),
)
doAssert authenticate(
  authenticatorFor(emptyTenant), "Bearer opaque-token", now,
).isNone

let expiredAtNow = scripted(
  200, $(%*{"active": true, "sub": "user-1", "tenant": "local", "exp": now}),
)
doAssert authenticate(
  authenticatorFor(expiredAtNow), "Bearer opaque-token", now,
).isNone

let expiredBefore = scripted(
  200, $(%*{"active": true, "sub": "user-1", "tenant": "local", "exp": now - 1}),
)
doAssert authenticate(
  authenticatorFor(expiredBefore), "Bearer opaque-token", now,
).isNone

let malformed = scripted(200, "{not json")
doAssert authenticate(
  authenticatorFor(malformed), "Bearer opaque-token", now,
).isNone

let denied = scripted(401, $(%*{"active": true}))
doAssert authenticate(
  authenticatorFor(denied), "Bearer opaque-token", now,
).isNone

let unavailable = scripted(200, "{}")
unavailable.unavailable = true
doAssert authenticate(
  authenticatorFor(unavailable), "Bearer opaque-token", now,
).isNone

let custom = scripted(
  200,
  $(%*{"active": true, "sub": "user-1", "org": "acme", "exp": now + 60}),
)
let customPrincipal = authenticate(
  authenticatorFor(custom, tenantClaim = "org"), "Bearer opaque-token", now,
)
doAssert customPrincipal.isSome
doAssert customPrincipal.get().tenant == "acme"

let revoker = revokerFor(active)
doAssert revoke(revoker, "opaque-token")
doAssert active.forms[^1]["token"] == "opaque-token"
doAssert active.forms[^1]["token_type_hint"] == "access_token"

let failedRevocation = scripted(503, "{}")
var caught = false
try:
  discard revoke(revokerFor(failedRevocation), "opaque-token")
except AuthError:
  caught = true
doAssert caught

let unavailableRevocation = scripted(200, "{}")
unavailableRevocation.unavailable = true
caught = false
try:
  discard revoke(revokerFor(unavailableRevocation), "opaque-token")
except AuthError:
  caught = true
doAssert caught

caught = false
try:
  discard revoke(revoker, "")
except AuthError:
  caught = true
doAssert caught

echo "Nim service auth tests passed"
