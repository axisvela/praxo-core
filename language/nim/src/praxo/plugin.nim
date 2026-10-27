import std/json
import std/strutils

import ./errors
import ./jsonutil

type
  Manifest* = object
    schemaVersion*: int
    id*: string
    version*: string
    kind*: string
    entrypoint*: JsonNode
    protocol*: string
    capabilities*: seq[string]
    permissions*: JsonNode
    limits*: JsonNode
    isolation*: string
    health*: JsonNode

const
  knownKinds = @[
    "tool.provider.v1",
    "model.provider.v1",
    "policy.provider.v1",
    "memory.provider.v1",
    "sandbox.provider.v1",
  ]
  manifestKeys = @[
    "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
    "capabilities", "permissions", "limits", "isolation", "health",
    "signature", "sbom",
  ]
  entrypointKeys = @["type", "command", "module", "image", "args", "dir"]
  permissionKeys = @["filesystem", "network", "env"]
  limitKeys = @["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"]
  healthKeys = @["method", "intervalMs"]
  signatureKeys = @["algorithm", "keyId"]

proc checkKeys(value: JsonNode, allowed: seq[string], where: string) =
  for key in value.keys:
    if key notin allowed:
      raisePraxo("PLUGIN_INVALID", "plugin: manifest: unknown field " & key & " in " & where)

proc objectField(value: JsonNode, where: string): JsonNode =
  if value.isNil or value.kind == JNull:
    return newJObject()
  if value.kind == JObject:
    return value
  raisePraxo("PLUGIN_INVALID", "plugin: manifest: " & where & " must be an object")

proc stringField(value: JsonNode, where: string): string =
  if value.isNil or value.kind != JString:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: " & where & " must be a string")
  return value.getStr()

proc integerField(value: JsonNode, where: string): int =
  if value.isNil:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: " & where & " must be an integer")
  if value.kind == JInt:
    return value.getInt()
  if value.kind == JFloat:
    let number = value.getFloat()
    if number == float(int(number)):
      return int(number)
  raisePraxo("PLUGIN_INVALID", "plugin: manifest: " & where & " must be an integer")

proc textPresent(value: JsonNode): bool =
  return not value.isNil and value.kind == JString and value.getStr().len > 0

proc isLowerAlphaNum(character: char): bool =
  return character in {'a'..'z', '0'..'9'}

proc validReverseDns(id: string): bool =
  let parts = id.split('.')
  if parts.len < 2:
    return false
  for part in parts:
    if part.len == 0 or part.len > 63:
      return false
    if not isLowerAlphaNum(part[0]) or not isLowerAlphaNum(part[^1]):
      return false
    for character in part:
      if not isLowerAlphaNum(character) and character != '-':
        return false
  return true

proc validSemver(version: string): bool =
  var core = version
  let dash = core.find('-')
  if dash >= 0:
    core = core[0 ..< dash]
  let plus = core.find('+')
  if plus >= 0:
    core = core[0 ..< plus]
  let parts = core.split('.')
  if parts.len != 3:
    return false
  for part in parts:
    if part.len == 0:
      return false
    if part.len > 1 and part[0] == '0':
      return false
    for character in part:
      if character notin {'0'..'9'}:
        return false
  return true

proc parseManifest*(raw: string): Manifest =
  if raw.strip().len == 0:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest is empty")
  var root: JsonNode
  try:
    root = parseJson(raw)
  except JsonParsingError as error:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: " & error.msg)
  if root.kind != JObject:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest must be an object")
  checkKeys(root, manifestKeys, "manifest")
  let schemaVersion = integerField(getNode(root, "schemaVersion"), "schemaVersion")
  if schemaVersion != 1:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: schemaVersion = " & $schemaVersion & ", want 1")
  let id = stringField(getNode(root, "id"), "id")
  if not validReverseDns(id):
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: id " & id & " is not reverse-DNS")
  let version = stringField(getNode(root, "version"), "version")
  if not validSemver(version):
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: version " & version & " is not semver")
  let kind = stringField(getNode(root, "kind"), "kind")
  if kind notin knownKinds:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: kind " & kind & " is not a known contract")
  let protocol = stringField(getNode(root, "protocol"), "protocol")
  if protocol != "jsonrpc-2":
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: protocol = " & protocol & ", want jsonrpc-2")
  let entrypoint = objectField(getNode(root, "entrypoint"), "entrypoint")
  checkKeys(entrypoint, entrypointKeys, "entrypoint")
  let entryType = stringField(getNode(entrypoint, "type"), "entrypoint.type")
  var requiredField = ""
  case entryType
  of "process":
    requiredField = "command"
  of "wasm":
    requiredField = "module"
  of "container":
    requiredField = "image"
  else:
    raisePraxo("PLUGIN_INVALID", "plugin: manifest: unknown entrypoint type " & entryType)
  if not textPresent(getNode(entrypoint, requiredField)):
    raisePraxo("PLUGIN_INVALID",
      "plugin: manifest: " & entryType & " entrypoint requires " & requiredField)
  let isolation = stringField(getNode(root, "isolation"), "isolation")
  if isolation != entryType:
    raisePraxo("PLUGIN_INVALID",
      "plugin: manifest: isolation " & isolation & " does not match entrypoint " & entryType)
  let permissions = objectField(getNode(root, "permissions"), "permissions")
  checkKeys(permissions, permissionKeys, "permissions")
  let limits = objectField(getNode(root, "limits"), "limits")
  checkKeys(limits, limitKeys, "limits")
  for key in limits.keys:
    if integerField(limits[key], "limits." & key) < 0:
      raisePraxo("PLUGIN_INVALID", "plugin: manifest: limits must not be negative")
  let health = objectField(getNode(root, "health"), "health")
  checkKeys(health, healthKeys, "health")
  let signature = getNode(root, "signature")
  if not signature.isNil and signature.kind != JNull:
    let signatureObject = objectField(signature, "signature")
    checkKeys(signatureObject, signatureKeys, "signature")
    if not textPresent(getNode(signatureObject, "algorithm")) or
        not textPresent(getNode(signatureObject, "keyId")):
      raisePraxo("PLUGIN_INVALID", "plugin: manifest: signature requires algorithm and keyId")
  var capabilities: seq[string] = @[]
  let capabilityValue = getNode(root, "capabilities")
  if not capabilityValue.isNil and capabilityValue.kind != JNull:
    if capabilityValue.kind != JArray:
      raisePraxo("PLUGIN_INVALID", "plugin: manifest: capabilities must be an array")
    var seen: seq[string] = @[]
    for item in capabilityValue.getElems():
      let capability = stringField(item, "capabilities")
      if capability.len == 0:
        raisePraxo("PLUGIN_INVALID", "plugin: manifest: capability must not be empty")
      if capability in seen:
        raisePraxo("PLUGIN_INVALID", "plugin: manifest: duplicate capability")
      seen.add(capability)
      capabilities.add(capability)
  return Manifest(
    schemaVersion: schemaVersion,
    id: id,
    version: version,
    kind: kind,
    entrypoint: entrypoint,
    protocol: protocol,
    capabilities: capabilities,
    permissions: permissions,
    limits: limits,
    isolation: isolation,
    health: health
  )
