import std/json
import std/math
import std/unicode

import ./jsonutil
import ./pattern

type
  ValidationError* = object
    path*: string
    message*: string

proc addError(errors: var seq[ValidationError], path: string, message: string) =
  errors.add(ValidationError(path: path, message: message))

proc checkEnum(schema: JsonNode, data: JsonNode, path: string,
               errors: var seq[ValidationError]) =
  let values = getArray(schema, "enum")
  if values.len == 0:
    return
  for value in values:
    if jsonEquals(value, data):
      return
  addError(errors, path, "value not in enum")

proc visitSchema(schema: JsonNode, data: JsonNode, path: string,
                 errors: var seq[ValidationError])

proc visitObject(schema: JsonNode, data: JsonNode, path: string,
                 errors: var seq[ValidationError]) =
  if data.kind != JObject:
    addError(errors, path, "expected object")
    return
  for item in getArray(schema, "required"):
    if item.kind == JString:
      let name = item.getStr()
      if not data.hasKey(name):
        addError(errors, path & "." & name, "required field missing")
  let properties = getObject(schema, "properties")
  if not properties.isNil:
    for name in properties.keys:
      if data.hasKey(name):
        visitSchema(properties[name], data[name], path & "." & name, errors)

proc visitArray(schema: JsonNode, data: JsonNode, path: string,
                errors: var seq[ValidationError]) =
  if data.kind != JArray:
    addError(errors, path, "expected array")
    return
  let items = getObject(schema, "items")
  if not items.isNil:
    for index, value in data.getElems():
      visitSchema(items, value, path & "[" & $index & "]", errors)

proc visitString(schema: JsonNode, data: JsonNode, path: string,
                 errors: var seq[ValidationError]) =
  if data.kind != JString:
    addError(errors, path, "expected string")
    return
  let value = data.getStr()
  let length = runeLen(value)
  let minimum = getInt(schema, "minLength", 0)
  let maximum = getInt(schema, "maxLength", 0)
  if minimum > 0 and length < minimum:
    addError(errors, path, "min length " & $minimum & ", got " & $length)
  if maximum > 0 and length > maximum:
    addError(errors, path, "max length " & $maximum & ", got " & $length)
  if schema.hasKey("pattern") and schema["pattern"].kind == JString:
    let pattern = schema["pattern"].getStr()
    if not patternMatches(value, pattern):
      addError(errors, path, "pattern '" & pattern & "' not matched")
  checkEnum(schema, data, path, errors)

proc visitNumber(schema: JsonNode, kind: string, data: JsonNode, path: string,
                 errors: var seq[ValidationError]) =
  if data.kind notin {JInt, JFloat}:
    addError(errors, path, "expected number")
    return
  let value = numberValue(data)
  if kind == "integer" and value != floor(value):
    addError(errors, path, "expected integer, got " & $value)
    return
  checkEnum(schema, data, path, errors)
  if schema.hasKey("minimum") and schema["minimum"].kind in {JInt, JFloat}:
    let minimum = numberValue(schema["minimum"])
    if minimum != 0.0 and value < minimum:
      addError(errors, path, "value below minimum")
  if schema.hasKey("maximum") and schema["maximum"].kind in {JInt, JFloat}:
    let maximum = numberValue(schema["maximum"])
    if maximum != 0.0 and value > maximum:
      addError(errors, path, "value above maximum")

proc visitSchema(schema: JsonNode, data: JsonNode, path: string,
                 errors: var seq[ValidationError]) =
  if schema.isNil or schema.kind != JObject:
    return
  let kind = getString(schema, "type")
  if isNullNode(data):
    if kind.len > 0:
      addError(errors, path, "expected " & kind & ", got null")
    return
  case kind
  of "object":
    visitObject(schema, data, path, errors)
  of "array":
    visitArray(schema, data, path, errors)
  of "string":
    visitString(schema, data, path, errors)
  of "number", "integer":
    visitNumber(schema, kind, data, path, errors)
  of "boolean":
    if data.kind != JBool:
      addError(errors, path, "expected boolean")
    else:
      checkEnum(schema, data, path, errors)
  else:
    discard

proc validateSchema*(schema: JsonNode, data: JsonNode): seq[ValidationError] =
  var errors: seq[ValidationError] = @[]
  visitSchema(schema, data, "$", errors)
  return errors
