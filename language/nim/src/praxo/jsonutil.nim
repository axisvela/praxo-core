import std/json
import std/math

proc parseJsonText*(text: string): JsonNode =
  parseJson(text)

proc encodeJson*(node: JsonNode): string =
  $node

proc isNullNode*(node: JsonNode): bool =
  node.isNil or node.kind == JNull

proc asObject*(node: JsonNode): JsonNode =
  if not node.isNil and node.kind == JObject:
    return node
  return nil

proc asArray*(node: JsonNode): seq[JsonNode] =
  if not node.isNil and node.kind == JArray:
    return node.getElems()
  return @[]

proc getNode*(node: JsonNode, key: string): JsonNode =
  if not node.isNil and node.kind == JObject and node.hasKey(key):
    return node[key]
  return nil

proc getString*(node: JsonNode, key: string, fallback: string = ""): string =
  let value = getNode(node, key)
  if not value.isNil and value.kind == JString:
    return value.getStr()
  return fallback

proc getBool*(node: JsonNode, key: string, fallback: bool = false): bool =
  let value = getNode(node, key)
  if not value.isNil and value.kind == JBool:
    return value.getBool()
  return fallback

proc getInt*(node: JsonNode, key: string, fallback: int = 0): int =
  let value = getNode(node, key)
  if value.isNil:
    return fallback
  if value.kind == JInt:
    return value.getInt()
  if value.kind == JFloat:
    let number = value.getFloat()
    if number == floor(number):
      return int(number)
  return fallback

proc getFloat*(node: JsonNode, key: string, fallback: float = 0.0): float =
  let value = getNode(node, key)
  if value.isNil:
    return fallback
  if value.kind == JInt:
    return float(value.getInt())
  if value.kind == JFloat:
    return value.getFloat()
  return fallback

proc getArray*(node: JsonNode, key: string): seq[JsonNode] =
  return asArray(getNode(node, key))

proc getObject*(node: JsonNode, key: string): JsonNode =
  return asObject(getNode(node, key))

proc numberValue*(node: JsonNode): float =
  if node.kind == JInt:
    return float(node.getInt())
  if node.kind == JFloat:
    return node.getFloat()
  return 0.0

proc jsonEquals*(left: JsonNode, right: JsonNode): bool =
  if left.isNil or right.isNil:
    return left.isNil and right.isNil
  if left.kind == JNull or right.kind == JNull:
    return left.kind == JNull and right.kind == JNull
  case left.kind
  of JObject:
    if right.kind != JObject or left.len != right.len:
      return false
    for key in left.keys:
      if not right.hasKey(key):
        return false
      if not jsonEquals(left[key], right[key]):
        return false
    return true
  of JArray:
    if right.kind != JArray or left.len != right.len:
      return false
    for index in 0 ..< left.len:
      if not jsonEquals(left[index], right[index]):
        return false
    return true
  of JString:
    return right.kind == JString and left.getStr() == right.getStr()
  of JInt, JFloat:
    if right.kind in {JInt, JFloat}:
      return numberValue(left) == numberValue(right)
    return false
  of JBool:
    return right.kind == JBool and left.getBool() == right.getBool()
  else:
    return false

proc fromStrings*(values: seq[string]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)

proc fromInts*(values: seq[int]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)
