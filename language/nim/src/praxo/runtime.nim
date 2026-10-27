import std/json
import std/strutils
import std/tables
import std/times

import ./errors
import ./jsonutil
import ./models

type
  Sink* = ref object
    kinds*: seq[string]
    mode*: string
    predicate*: seq[string]
    target*: Sink
    sinks*: seq[Sink]

  MemoryStore* = ref object
    records*: Table[string, seq[MemoryRecord]]
    sequence*: int

  CheckpointAllowlist* = ref object
    registered*: Table[string, bool]

  PathChecker* = object
    grants*: seq[PathGrant]

proc emit*(sink: Sink, event: Event) =
  if sink.mode == "filter":
    if sink.predicate.len == 0 or event.kind in sink.predicate:
      if not sink.target.isNil:
        sink.target.emit(event)
    return
  if sink.mode == "multi":
    for child in sink.sinks:
      child.emit(event)
    return
  sink.kinds.add(event.kind)

proc newSink*(): Sink =
  Sink()

proc multiSink*(sinks: seq[Sink]): Sink =
  Sink(mode: "multi", sinks: sinks)

proc filterSink*(target: Sink, predicate: seq[string]): Sink =
  Sink(mode: "filter", target: target, predicate: predicate)

proc newMemoryStore*(): MemoryStore =
  MemoryStore(records: initTable[string, seq[MemoryRecord]]())

proc memoryPut*(store: MemoryStore, sessionId: string, record: MemoryRecord): MemoryRecord =
  var value = record
  if value.id.len == 0:
    value.id = "mem-" & $getTime().toUnix() & "-" & $store.sequence
    inc store.sequence
  if value.createdAt.len == 0:
    value.createdAt = $getTime().toUnix()
  store.records.mgetOrPut(sessionId, @[]).add(value)
  return value

proc memorySearch*(store: MemoryStore, sessionId: string, query: string,
                   limit: int): seq[MemoryRecord] =
  let records = store.records.getOrDefault(sessionId, @[])
  let needle = query.strip().toLowerAscii()
  var matches: seq[MemoryRecord] = @[]
  for record in records:
    if needle.len == 0 or record.content.toLowerAscii().contains(needle):
      matches.add(record)
  var index = 1
  while index < matches.len:
    let current = matches[index]
    var position = index
    while position > 0 and matches[position - 1].createdAt < current.createdAt:
      matches[position] = matches[position - 1]
      dec position
    matches[position] = current
    inc index
  if limit > 0 and matches.len > limit:
    return matches[0 ..< limit]
  return matches

proc newCheckpointAllowlist*(): CheckpointAllowlist =
  CheckpointAllowlist(registered: initTable[string, bool]())

proc register*(allow: CheckpointAllowlist, kind: string) =
  if kind.len == 0:
    raisePraxo("CHECKPOINT_ERROR", "checkpoint: type is required")
  allow.registered[kind] = true

proc marshal*(allow: CheckpointAllowlist, kind: string, value: JsonNode): string =
  if not allow.registered.hasKey(kind):
    raisePraxo("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed")
  var envelope = newJObject()
  envelope["type"] = %kind
  envelope["data"] = if value.isNil: newJNull() else: value
  return encodeJson(envelope)

proc unmarshal*(allow: CheckpointAllowlist, data: string): JsonNode =
  var envelope: JsonNode
  try:
    envelope = parseJson(data)
  except JsonParsingError:
    raisePraxo("CHECKPOINT_ERROR", "checkpoint: invalid envelope")
  if envelope.kind != JObject:
    raisePraxo("CHECKPOINT_ERROR", "checkpoint: envelope must be an object")
  let kind = getString(envelope, "type")
  if not allow.registered.hasKey(kind):
    raisePraxo("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed")
  result = getNode(envelope, "data")
  if result.isNil:
    result = newJNull()

proc normalizePath*(value: string): string =
  var path = value.replace("\\", "/")
  var prefix = ""
  if path.len >= 2 and path[1] == ':':
    prefix = path[0 .. 1]
    path = if path.len > 2: path[2 .. ^1] else: ""
  elif path.startsWith("/"):
    prefix = "/"
  let rooted = path.startsWith("/")
  var parts: seq[string] = @[]
  for part in path.split('/'):
    if part.len == 0 or part == ".":
      continue
    if part == "..":
      if parts.len > 0 and parts[^1] != "..":
        discard parts.pop()
      elif not rooted:
        parts.add(part)
      continue
    parts.add(part)
  result = prefix & parts.join("/")
  when defined(windows):
    result = result.toLowerAscii()

proc pathWithin(root: string, target: string): bool =
  if root == target:
    return true
  return target.startsWith(root & "/")

proc accessAllows(grant: string, need: string): bool =
  if need == "read":
    return grant == "read" or grant == "readwrite"
  if need == "write":
    return grant == "write" or grant == "readwrite"
  return grant == "readwrite"

proc newPathChecker*(grants: seq[PathGrant]): PathChecker =
  var normalized: seq[PathGrant] = @[]
  for grant in grants:
    if grant.root.len == 0:
      raisePraxo("POLICY_ERROR", "policy: path grant root is required")
    if grant.access notin ["read", "write", "readwrite"]:
      raisePraxo("POLICY_ERROR", "policy: invalid grant access")
    normalized.add(PathGrant(root: normalizePath(grant.root), access: grant.access))
  return PathChecker(grants: normalized)

proc check*(checker: PathChecker, target: string, need: string): Decision =
  if need notin ["read", "write", "readwrite"]:
    raisePraxo("POLICY_ERROR", "policy: invalid requested access")
  if checker.grants.len == 0:
    return newDecision(false, "no allowed roots")
  let resolved = normalizePath(target)
  var matched = false
  for grant in checker.grants:
    if pathWithin(grant.root, resolved):
      matched = true
      if accessAllows(grant.access, need):
        return newDecision(true, "allowed")
  let reason = if matched: "insufficient grant" else: "outside roots"
  return newDecision(false, reason)

proc pathAllowed*(checker: PathChecker, target: string, need: string): bool =
  try:
    return check(checker, target, need).allowed
  except PraxoError:
    return false

proc estimateTokens*(messages: seq[Message]): int =
  var total = 0
  for item in messages:
    total = total + 4 + item.content.len div 4 + item.toolId.len div 4
    for entry in item.contentBlocks:
      total = total + 4 + entry.text.len div 4
    for call in item.toolCalls:
      let arguments = if call.arguments.isNil: newJObject() else: call.arguments
      total = total + 4 + call.name.len div 4 + encodeJson(arguments).len div 4
  return total

proc truncateToTokens*(value: string, tokens: int): string =
  if tokens <= 0:
    return ""
  let limit = tokens * 4
  if value.len <= limit:
    return value
  if limit <= 16:
    return value[0 ..< limit]
  return value[0 ..< limit - 16] & "\n[truncated]"

proc compactContext*(budget: ContextBudget, messages: seq[Message]): tuple[output: seq[Message], ok: bool] =
  if budget.maxTokens <= 0 or estimateTokens(messages) <= budget.maxTokens:
    return (messages, true)
  var system: seq[Message] = @[]
  var rest: seq[Message] = @[]
  for item in messages:
    if item.role == ROLE_SYSTEM:
      if not item.content.startsWith("[context compacted:"):
        system.add(item)
    else:
      rest.add(item)
  if estimateTokens(system) > budget.maxTokens:
    if system.len == 0:
      return (@[], false)
    let first = system[0]
    system = @[Message(
      role: first.role,
      content: truncateToTokens(first.content, budget.maxTokens - 4),
      contentBlocks: first.contentBlocks,
      toolCalls: first.toolCalls,
      toolId: first.toolId
    )]
    if estimateTokens(system) > budget.maxTokens:
      return (@[], false)
  let keep = if budget.keepRecent > 0: budget.keepRecent else: 4
  var start = if rest.len > keep: rest.len - keep else: 0
  while start > 0 and rest[start].role == ROLE_TOOL:
    dec start
  let marker = newMessage(ROLE_SYSTEM,
    "[context compacted: " & $start & " older messages omitted]")
  var kept = if start >= rest.len: @[] else: rest[start .. ^1]
  var output: seq[Message] = @[]
  output.add(system)
  if start > 0:
    output.add(marker)
  output.add(kept)
  while estimateTokens(output) > budget.maxTokens and kept.len > 1:
    if kept[1].role == ROLE_TOOL:
      break
    kept = kept[1 .. ^1]
    output = @[]
    output.add(system)
    if start > 0:
      output.add(marker)
    output.add(kept)
  return (output, estimateTokens(output) <= budget.maxTokens)
