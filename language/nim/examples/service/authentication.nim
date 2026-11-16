import std/json
import std/base64
import std/options
import std/strutils
import std/tables

type
  Principal* = object
    subject*: string
    tenant*: string
    expires*: int

  AuthError* = object of CatchableError

  IntrospectionTransport* = proc(
    url: string,
    form: Table[string, string],
    authorization: Option[string]
  ): (int, string)

  IntrospectionAuthenticator* = object
    transport*: IntrospectionTransport
    endpoint*: string
    clientId*: string
    clientSecret*: string
    tenantClaim*: string

  RevocationClient* = object
    transport*: IntrospectionTransport
    endpoint*: string
    clientId*: string
    clientSecret*: string

proc basicAuth(clientId, clientSecret: string): Option[string] =
  if clientId.len == 0:
    return none(string)
  return some("Basic " & base64.encode(clientId & ":" & clientSecret))

proc newIntrospectionAuthenticator*(
  transport: IntrospectionTransport,
  endpoint: string,
  clientId: string = "",
  clientSecret: string = "",
  tenantClaim: string = "tenant",
): IntrospectionAuthenticator =
  let claim = if tenantClaim.len == 0: "tenant" else: tenantClaim
  return IntrospectionAuthenticator(
    transport: transport,
    endpoint: endpoint,
    clientId: clientId,
    clientSecret: clientSecret,
    tenantClaim: claim,
  )

proc authenticate*(
  authenticator: IntrospectionAuthenticator,
  authorization: string,
  now: int,
): Option[Principal] =
  if not authorization.startsWith("Bearer "):
    return none(Principal)
  let token = if authorization.len > 7:
    authorization[7 .. ^1].strip()
  else:
    ""
  if token.len == 0:
    return none(Principal)
  var form = initTable[string, string]()
  form["token"] = token
  form["client_id"] = authenticator.clientId
  form["client_secret"] = authenticator.clientSecret
  var status = 0
  var body = ""
  try:
    let response = authenticator.transport(
      authenticator.endpoint,
      form,
      basicAuth(authenticator.clientId, authenticator.clientSecret),
    )
    status = response[0]
    body = response[1]
  except CatchableError:
    return none(Principal)
  if status != 200:
    return none(Principal)
  var payload: JsonNode
  try:
    payload = parseJson(body)
  except CatchableError:
    return none(Principal)
  if payload.kind != JObject:
    return none(Principal)
  if not payload.hasKey("active"):
    return none(Principal)
  let active = payload["active"]
  if active.kind != JBool or not active.getBool():
    return none(Principal)
  if not payload.hasKey("sub"):
    return none(Principal)
  let subjectNode = payload["sub"]
  if subjectNode.kind != JString:
    return none(Principal)
  let subject = subjectNode.getStr()
  if subject.len == 0:
    return none(Principal)
  if not payload.hasKey(authenticator.tenantClaim):
    return none(Principal)
  let tenantNode = payload[authenticator.tenantClaim]
  if tenantNode.kind != JString:
    return none(Principal)
  let tenant = tenantNode.getStr()
  if tenant.len == 0:
    return none(Principal)
  if not payload.hasKey("exp"):
    return none(Principal)
  let expiresNode = payload["exp"]
  if expiresNode.kind != JInt:
    return none(Principal)
  let expires = int(expiresNode.getInt())
  if expires <= now:
    return none(Principal)
  return some(Principal(subject: subject, tenant: tenant, expires: expires))

proc newRevocationClient*(
  transport: IntrospectionTransport,
  endpoint: string,
  clientId: string = "",
  clientSecret: string = "",
): RevocationClient =
  return RevocationClient(
    transport: transport,
    endpoint: endpoint,
    clientId: clientId,
    clientSecret: clientSecret,
  )

proc revoke*(client: RevocationClient, token: string): bool =
  if token.len == 0:
    raise newException(AuthError, "revocation token is required")
  var form = initTable[string, string]()
  form["token"] = token
  form["token_type_hint"] = "access_token"
  form["client_id"] = client.clientId
  form["client_secret"] = client.clientSecret
  var status = 0
  try:
    let response = client.transport(
      client.endpoint,
      form,
      basicAuth(client.clientId, client.clientSecret),
    )
    status = response[0]
  except CatchableError:
    raise newException(AuthError, "token revocation failed")
  if status != 200:
    raise newException(AuthError, "token revocation failed")
  return true
