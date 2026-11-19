import std/os
import praxo/plugin_process

proc main() =
  let python = block:
    let configured = getEnv("PRAXO_PYTHON")
    if configured.len > 0:
      configured
    elif defined(windows):
      "python"
    else:
      "python3"
  let fixture = currentSourcePath().parentDir / "fixtures" / "process_plugin.py"
  let host = ProcessHost()
  start(host, "com.example.echo", python, fixture, "")
  try:
    doAssert invoke(host, "tool.provider", "echo", "{\"text\":\"hi\"}") ==
      "{\"text\":\"hi\"}"
    echo "nim plugin process tests passed"
  finally:
    stop(host)

main()
