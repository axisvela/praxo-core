import praxo/runtime
import praxo/models

let all = newSink()
let tool = newSink()
let filtered = filterSink(tool, @["tool.call"])
let multi = multiSink(@[all, filtered])
for kind in ["run.started", "tool.call", "run.completed"]:
  multi.emit(newEvent(kind, "s1"))
doAssert all.kinds == @["run.started", "tool.call", "run.completed"]
doAssert tool.kinds == @["tool.call"]
echo "Nim event sink example passed"
