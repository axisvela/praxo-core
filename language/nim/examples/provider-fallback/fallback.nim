proc runFallback(primaryFails, fallbackFails: bool): string =
  if not primaryFails: return "primary"
  if not fallbackFails: return "fallback"
  "MODEL_UNAVAILABLE"

doAssert runFallback(false, false) == "primary"
doAssert runFallback(true, false) == "fallback"
doAssert runFallback(true, true) == "MODEL_UNAVAILABLE"
echo "Nim provider fallback example passed"
