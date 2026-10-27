type
  TokenKind = enum
    tkLiteral, tkAny, tkDigit, tkWord, tkSpace, tkClass

  Token = object
    kind: TokenKind
    literal: char
    ranges: seq[(char, char)]
    negated: bool
    quantifier: char

proc addRange(token: var Token, first: char, last: char) =
  token.ranges.add((first, last))

proc parseClass(pattern: string, start: int): tuple[token: Token, next: int] =
  result.token.kind = tkClass
  var index = start + 1
  if index < pattern.len and pattern[index] == '^':
    result.token.negated = true
    inc index
  while index < pattern.len and pattern[index] != ']':
    var first = pattern[index]
    if first == '\\' and index + 1 < pattern.len:
      inc index
      first = pattern[index]
      case first
      of 'd':
        result.token.addRange('0', '9')
        inc index
        continue
      of 'w':
        result.token.addRange('a', 'z')
        result.token.addRange('A', 'Z')
        result.token.addRange('0', '9')
        result.token.addRange('_', '_')
        inc index
        continue
      of 's':
        result.token.addRange(' ', ' ')
        result.token.addRange('\t', '\t')
        result.token.addRange('\n', '\n')
        inc index
        continue
      else:
        discard
    if index + 2 < pattern.len and pattern[index + 1] == '-' and pattern[index + 2] != ']':
      let last = pattern[index + 2]
      result.token.addRange(first, last)
      index += 3
    else:
      result.token.addRange(first, first)
      inc index
  result.next = index + 1

proc parsePattern(pattern: string): tuple[tokens: seq[Token], anchoredStart: bool, anchoredEnd: bool] =
  var index = 0
  if index < pattern.len and pattern[index] == '^':
    result.anchoredStart = true
    inc index
  if pattern.len > index and pattern[pattern.len - 1] == '$' and
      (pattern.len < 2 or pattern[pattern.len - 2] != '\\'):
    result.anchoredEnd = true
  let limit = if result.anchoredEnd: pattern.len - 1 else: pattern.len
  while index < limit:
    var token: Token
    let character = pattern[index]
    if character == '\\' and index + 1 < limit:
      inc index
      let escaped = pattern[index]
      case escaped
      of 'd':
        token.kind = tkDigit
      of 'w':
        token.kind = tkWord
      of 's':
        token.kind = tkSpace
      else:
        token.kind = tkLiteral
        token.literal = escaped
    elif character == '.':
      token.kind = tkAny
    elif character == '[':
      let parsed = parseClass(pattern, index)
      token = parsed.token
      index = parsed.next - 1
    else:
      token.kind = tkLiteral
      token.literal = character
    if index + 1 < limit and pattern[index + 1] in {'*', '+', '?'}:
      token.quantifier = pattern[index + 1]
      inc index
    result.tokens.add(token)
    inc index

proc isWord(character: char): bool =
  return character in {'a'..'z', 'A'..'Z', '0'..'9', '_'}

proc atomMatches(token: Token, character: char): bool =
  case token.kind
  of tkLiteral:
    return character == token.literal
  of tkAny:
    return character != '\n'
  of tkDigit:
    return character in {'0'..'9'}
  of tkWord:
    return isWord(character)
  of tkSpace:
    return character in {' ', '\t', '\n', '\r'}
  of tkClass:
    var found = false
    for (first, last) in token.ranges:
      if character >= first and character <= last:
        found = true
        break
    if token.negated:
      return not found
    return found

proc matchFrom(tokens: seq[Token], tokenIndex: int, text: string, textIndex: int,
               anchoredEnd: bool): bool =
  if tokenIndex >= tokens.len:
    return (not anchoredEnd) or textIndex == text.len
  let token = tokens[tokenIndex]
  case token.quantifier
  of '?':
    if matchFrom(tokens, tokenIndex + 1, text, textIndex, anchoredEnd):
      return true
    if textIndex < text.len and atomMatches(token, text[textIndex]):
      return matchFrom(tokens, tokenIndex + 1, text, textIndex + 1, anchoredEnd)
    return false
  of '*', '+':
    var ends: seq[int] = @[]
    var position = textIndex
    if token.quantifier == '+':
      if position >= text.len or not atomMatches(token, text[position]):
        return false
      inc position
    ends.add(position)
    while position < text.len and atomMatches(token, text[position]):
      inc position
      ends.add(position)
    for index in countdown(ends.len - 1, 0):
      if matchFrom(tokens, tokenIndex + 1, text, ends[index], anchoredEnd):
        return true
    return false
  else:
    if textIndex < text.len and atomMatches(token, text[textIndex]):
      return matchFrom(tokens, tokenIndex + 1, text, textIndex + 1, anchoredEnd)
    return false

proc patternMatches*(value: string, pattern: string): bool =
  let parsed = parsePattern(pattern)
  if parsed.anchoredStart:
    return matchFrom(parsed.tokens, 0, value, 0, parsed.anchoredEnd)
  for start in 0 .. value.len:
    if matchFrom(parsed.tokens, 0, value, start, parsed.anchoredEnd):
      return true
  return false
