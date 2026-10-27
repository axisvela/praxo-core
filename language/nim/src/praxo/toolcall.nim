import std/json
import std/options
import std/strutils

import ./jsonutil
import ./models

proc parseInputJson*(raw: string): Option[JsonNode] =
  try:
    let value = parseJson(raw.strip())
    if value.kind == JObject:
      return some(value)
  except JsonParsingError:
    discard
  return none(JsonNode)

proc parseJsonCall(content: string): Option[ToolCall] =
  try:
    let value = parseJson(content)
    if value.kind != JObject:
      return none(ToolCall)
    let name = getString(value, "name")
    if name.len == 0:
      return none(ToolCall)
    var input = getObject(value, "input")
    if input.isNil:
      input = newJObject()
    return some(newToolCall("", name, input))
  except JsonParsingError:
    return none(ToolCall)

proc findMatchingBrace(text: string, start: int): int =
  var depth = 0
  var inString = false
  var escaped = false
  var index = start
  while index < text.len:
    let character = text[index]
    if inString:
      if escaped:
        escaped = false
      elif character == '\\':
        escaped = true
      elif character == '"':
        inString = false
    elif character == '"':
      inString = true
    elif character == '{':
      inc depth
    elif character == '}':
      dec depth
      if depth == 0:
        return index
    inc index
  return -1

proc parseXml(content: string): Option[ToolCall] =
  let start = content.rfind("<tool_call")
  if start < 0:
    return none(ToolCall)
  let rest = content[start .. ^1]
  let nameOpen = rest.find("name=\"")
  if nameOpen < 0:
    return none(ToolCall)
  let nameStart = nameOpen + 6
  let nameEnd = rest.find('"', nameStart)
  if nameEnd < 0:
    return none(ToolCall)
  let name = rest[nameStart ..< nameEnd]
  if name.len == 0:
    return none(ToolCall)
  let openEnd = rest.find('>', nameEnd + 1)
  if openEnd < 0:
    return none(ToolCall)
  let close = rest.rfind("</tool_call>")
  if close <= openEnd:
    return none(ToolCall)
  let input = parseInputJson(rest[openEnd + 1 ..< close])
  if input.isNone:
    return none(ToolCall)
  return some(newToolCall("", name, input.get()))

proc parseTag(content: string): Option[ToolCall] =
  var search = 0
  var name = ""
  var body = ""
  while true:
    let start = content.find('<', search)
    if start < 0:
      break
    let ending = content.find('>', start + 1)
    if ending < 0:
      break
    let candidate = content[start + 1 ..< ending].strip()
    search = ending + 1
    if candidate.len == 0 or candidate.startsWith("/") or candidate.contains(' ') or
        candidate.contains('\t') or candidate.contains('\n') or not candidate.contains('.'):
      continue
    let after = content[ending + 1 .. ^1].strip()
    if after.startsWith("{"):
      let braceEnd = findMatchingBrace(after, 0)
      if braceEnd < 0:
        continue
      name = candidate
      body = after[0 .. braceEnd]
    else:
      name = candidate
      body = after
  if name.len == 0:
    return none(ToolCall)
  let input = parseInputJson(body)
  if input.isNone:
    return none(ToolCall)
  return some(newToolCall("", name, input.get()))

proc parsePlain(content: string): Option[ToolCall] =
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("{"):
      continue
    let space = trimmed.find(' ')
    if space < 0:
      continue
    let name = trimmed[0 ..< space]
    if name.startsWith("<") or not name.contains('.'):
      continue
    let raw = trimmed[space + 1 .. ^1].strip()
    if not raw.startsWith("{"):
      continue
    let input = parseInputJson(raw)
    if input.isNone:
      continue
    return some(newToolCall("", name, input.get()))
  return none(ToolCall)

proc parseToolCall*(content: string): Option[ToolCall] =
  let asJson = parseJsonCall(content)
  if asJson.isSome:
    return asJson
  let asXml = parseXml(content)
  if asXml.isSome:
    return asXml
  let asTag = parseTag(content)
  if asTag.isSome:
    return asTag
  return parsePlain(content)

proc removeBetween(text: string, openPrefix: string, closeTag: string): string =
  result = text
  while true:
    let start = result.find(openPrefix)
    if start < 0:
      break
    let close = result.find(closeTag, start)
    if close < 0:
      break
    let ending = close + closeTag.len
    result = result[0 ..< start] & result[ending .. ^1]

proc removeDottedTags(text: string): string =
  result = text
  var search = 0
  while true:
    let start = result.find('<', search)
    if start < 0:
      break
    let ending = result.find('>', start + 1)
    if ending < 0:
      break
    let name = result[start + 1 ..< ending].strip()
    if name.len == 0 or name.startsWith("/") or not name.contains('.'):
      search = ending + 1
      continue
    let closeTag = "</" & name & ">"
    let close = result.find(closeTag, ending + 1)
    if close < 0:
      result = result[0 ..< start]
      break
    let finish = close + closeTag.len
    result = result[0 ..< start] & result[finish .. ^1]
    search = start

proc stripToolCallMarkup*(content: string): string =
  result = removeBetween(content, "<tool_call name=\"", "</tool_call>")
  result = removeBetween(result, "<tool_call_invoke>", "</tool_call_invoke>")
  result = removeDottedTags(result)
  while result.contains("\n\n\n"):
    result = result.replace("\n\n\n", "\n\n")
  result = result.strip()
