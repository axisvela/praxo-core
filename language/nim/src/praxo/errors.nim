import std/strutils

type
  PraxoError* = object of CatchableError

proc raisePraxo*(code: string, message: string) {.noreturn.} =
  raise newException(PraxoError, code & "|" & message)

proc errorCode*(error: ref CatchableError): string =
  let parts = error.msg.split('|', maxsplit = 1)
  if parts.len > 0:
    return parts[0]
  return ""
