import std/json
import std/options
import std/strutils

import ./errors
import ./jsonutil
import ./jsonschema
import ./models

proc isEmailLocal(character: char): bool =
  return character in {'a'..'z', 'A'..'Z', '0'..'9', '.', '_', '%', '+', '-'}

proc isDomainCharacter(character: char): bool =
  return character in {'a'..'z', 'A'..'Z', '0'..'9', '.', '-'}

proc isAlpha(character: char): bool =
  return character in {'a'..'z', 'A'..'Z'}

proc isDigit(character: char): bool =
  return character in {'0'..'9'}

proc redactEmail(text: string): string =
  result = ""
  var index = 0
  while index < text.len:
    if text[index] == '@':
      var start = index
      while start > 0 and isEmailLocal(text[start - 1]):
        dec start
      var ending = index + 1
      while ending < text.len and isDomainCharacter(text[ending]):
        inc ending
      while ending > index + 1 and text[ending - 1] == '.':
        dec ending
      if ending > index + 1:
        let domain = text[index + 1 ..< ending]
        let dot = domain.rfind('.')
        if dot > 0 and domain.len - dot - 1 >= 2:
          var validTld = true
          for position in dot + 1 ..< domain.len:
            if not isAlpha(domain[position]):
              validTld = false
          if validTld:
            result = result[0 ..< result.len - (index - start)]
            result.add("[REDACTED:email]")
            index = ending
            continue
    result.add(text[index])
    inc index

proc redactSsn(text: string): string =
  result = ""
  var index = 0
  while index < text.len:
    if index + 11 <= text.len and isDigit(text[index]) and isDigit(text[index + 1]) and
        isDigit(text[index + 2]) and text[index + 3] == '-' and isDigit(text[index + 4]) and
        isDigit(text[index + 5]) and text[index + 6] == '-' and isDigit(text[index + 7]) and
        isDigit(text[index + 8]) and isDigit(text[index + 9]) and isDigit(text[index + 10]):
      result.add("[REDACTED:ssn]")
      index += 11
      continue
    result.add(text[index])
    inc index

proc creditCardAt(text: string, start: int): int =
  var index = start
  for group in 0 ..< 4:
    if group > 0 and index < text.len and (text[index] == ' ' or text[index] == '-'):
      inc index
    for _ in 0 ..< 4:
      if index >= text.len or not isDigit(text[index]):
        return start
      inc index
  return index

proc redactCreditCard(text: string): string =
  result = ""
  var index = 0
  while index < text.len:
    let ending = creditCardAt(text, index)
    if ending > index:
      result.add("[REDACTED:credit_card]")
      index = ending
      continue
    result.add(text[index])
    inc index

proc redactPhone(text: string): string

proc piiRedact*(text: string): string =
  result = redactEmail(text)
  result = redactSsn(result)
  result = redactCreditCard(result)
  result = redactPhone(result)
proc redactValue*(value: JsonNode): JsonNode =
  if value.isNil:
    return value
  case value.kind
  of JString:
    return %piiRedact(value.getStr())
  of JArray:
    var items = newJArray()
    for item in value.getElems():
      items.add(redactValue(item))
    return items
  of JObject:
    var output = newJObject()
    for key in value.keys:
      output[key] = redactValue(value[key])
    return output
  else:
    return value

proc extractJson*(text: string): Option[JsonNode] =
  var value = text.strip()
  if value.len == 0:
    return none(JsonNode)
  if value.startsWith("```"):
    let newline = value.find('\n')
    if newline >= 0:
      value = value[newline + 1 .. ^1]
    let close = value.rfind("```")
    if close >= 0:
      value = value[0 ..< close]
    value = value.strip()
  let objectStart = value.find('{')
  let arrayStart = value.find('[')
  var start = -1
  if objectStart >= 0 and arrayStart >= 0:
    start = min(objectStart, arrayStart)
  elif objectStart >= 0:
    start = objectStart
  elif arrayStart >= 0:
    start = arrayStart
  if start < 0:
    return none(JsonNode)
  try:
    return some(parseJson(value[start .. ^1]))
  except JsonParsingError:
    return none(JsonNode)

type
  StructuredOutput* = object
    schema*: JsonNode
    maxRepairs*: int
    repairer*: proc(text: string): string {.closure.}

proc structuredOutput*(schema: JsonNode, maxRepairs: int,
                       repairer: proc(text: string): string {.closure.} = nil): StructuredOutput =
  return StructuredOutput(schema: schema, maxRepairs: maxRepairs, repairer: repairer)

proc apply*(config: StructuredOutput, text: string): tuple[output: string, code: string] =
  var output = text
  for attempt in 0 .. config.maxRepairs:
    let value = extractJson(output)
    if value.isSome and validateSchema(config.schema, value.get()).len == 0:
      return (output, "")
    if attempt == config.maxRepairs:
      break
    if config.repairer.isNil:
      break
    let repaired = config.repairer(output)
    if repaired.strip().len == 0:
      break
    output = repaired
  return ("", "AGENT_STRUCTURED_OUTPUT")

type
  CallLimit* = ref object
    modelLimit*: int
    toolLimit*: int
    models*: int
    tools*: int

  ToolSelection* = object
    selected*: seq[string]

proc callLimit*(modelLimit: int, toolLimit: int): CallLimit =
  return CallLimit(modelLimit: modelLimit, toolLimit: toolLimit)

proc modelCall*(limit: CallLimit) =
  inc limit.models
  if limit.modelLimit > 0 and limit.models > limit.modelLimit:
    raisePraxo("AGENT_MODEL_CALL_LIMIT", "model call limit")

proc toolCall*(limit: CallLimit) =
  inc limit.tools
  if limit.toolLimit > 0 and limit.tools > limit.toolLimit:
    raisePraxo("AGENT_TOOL_CALL_LIMIT", "tool call limit")

proc toolSelection*(selected: seq[string]): ToolSelection =
  return ToolSelection(selected: selected)

proc selectTools*(selection: ToolSelection, tools: seq[ToolSpec]): seq[ToolSpec] =
  var output: seq[ToolSpec] = @[]
  for tool in tools:
    if tool.name in selection.selected:
      output.add(tool)
  return output

proc checkToolSelected*(selection: ToolSelection, name: string) =
  if name notin selection.selected:
    raisePraxo("AGENT_TOOL_NOT_SELECTED", "tool not selected")
proc isWordChar(character: char): bool =
  return isAlpha(character) or isDigit(character) or character == '_'

proc takeDigits(text: string, start: int, count: int): int =
  var index = start
  for _ in 0 ..< count:
    if index >= text.len or not isDigit(text[index]):
      return -1
    inc index
  return index

proc skipSeparator(text: string, index: int): int =
  if index < text.len and (text[index] == '-' or text[index] == '.' or text[index] == ' '):
    return index + 1
  return index

proc phoneEndWithoutPrefix(text: string, start: int): int =
  var index = start
  if index < text.len and text[index] == '(':
    inc index
  index = takeDigits(text, index, 3)
  if index < 0:
    return start
  if index < text.len and text[index] == ')':
    inc index
  index = skipSeparator(text, index)
  index = takeDigits(text, index, 3)
  if index < 0:
    return start
  index = skipSeparator(text, index)
  index = takeDigits(text, index, 4)
  if index < 0:
    return start
  return index

proc phoneAt(text: string, start: int): int =
  if start > 0 and isWordChar(text[start - 1]):
    return start
  var best = start
  let direct = phoneEndWithoutPrefix(text, start)
  if direct > start and (direct >= text.len or not isWordChar(text[direct])):
    best = direct
  var index = start
  if index < text.len and text[index] == '+':
    if index + 1 < text.len and text[index + 1] == '1':
      index += 2
    else:
      return best
  elif index < text.len and text[index] == '1':
    inc index
  else:
    return best
  index = skipSeparator(text, index)
  let prefixed = phoneEndWithoutPrefix(text, index)
  if prefixed > index and (prefixed >= text.len or not isWordChar(text[prefixed])) and prefixed > best:
    best = prefixed
  return best

proc redactPhone(text: string): string =
  result = ""
  var index = 0
  while index < text.len:
    let ending = phoneAt(text, index)
    if ending > index:
      result.add("[REDACTED:phone]")
      index = ending
      continue
    result.add(text[index])
    inc index
