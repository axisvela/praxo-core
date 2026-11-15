import std/json
import std/os
import std/times
import praxo

const
  DefaultBaseUrl = "http://localhost:11434/v1"
  DefaultModel = "qwen3.5:4b"
  DefaultPrompt =
    "What time is it? Use get_time with zone set to utc and reply with the time."

let getTimeSchema = parseJsonText("""{
  "type": "object",
  "properties": {
    "zone": {
      "type": "string",
      "enum": ["utc", "local"],
      "description": "utc or local; defaults to utc"
    }
  }
}""")

proc envOr(name: string, fallback: string): string =
  let value = getEnv(name)
  return if value.len == 0: fallback else: value

proc getTime(arguments: JsonNode): JsonNode =
  let errors = validateSchema(getTimeSchema, arguments)
  if errors.len > 0:
    raisePraxo("TOOL_ARGUMENTS", "get_time arguments do not match the schema")
  let zone = getString(arguments, "zone", "utc")
  let stamp = if zone == "local": $now() else: $utc(now())
  return %stamp

proc main() =
  let baseUrl = envOr("PRAXO_BASE_URL", DefaultBaseUrl)
  let modelName = envOr("PRAXO_MODEL", DefaultModel)
  let apiKey = getEnv("PRAXO_API_KEY")
  let prompt = envOr("PRAXO_PROMPT", DefaultPrompt)

  let adapter = newOpenAICompatible(baseUrl, modelName, apiKey)
  let model = openaiModel(adapter)
  var options = newAgentOptions(model)
  options.tools = @[
    newTool("get_time",
            "Return the current time in ISO 8601 format for the requested zone.",
            getTime)
  ]
  options.systemPrompt =
    "You are a concise assistant. Use the provided tools when they help."
  options.maxSteps = 4
  options.allowedTools = @["get_time"]
  options.policy = proc(kind: string): bool =
    kind == "model.generate" or kind == "tool.invoke"
  options.requirePolicy = true
  options.requireToolScope = true

  try:
    let result = runAgent(options, newSession("live-model"), prompt)
    echo result.output
  except CatchableError as error:
    stderr.writeLine("live model run failed: " & error.msg & "\n\n" &
                     "Check PRAXO_BASE_URL (" & baseUrl & "), PRAXO_MODEL (" &
                     modelName & "), and PRAXO_API_KEY")
    quit(1)

main()
