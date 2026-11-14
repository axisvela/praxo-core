import PraxoCore

final class RecordingSink: EventSink {
    var types: [String] = []

    func emit(_ event: Event) {
        types.append(event.type)
    }
}

let all = RecordingSink()
let tool = RecordingSink()
let filtered = FilterSink(tool) { event in event.type == "tool.call" }
let multi = MultiSink([all, filtered])
for type in ["run.started", "tool.call", "run.completed"] {
    multi.emit(Event(type: type, sessionId: "s1"))
}
precondition(all.types == ["run.started", "tool.call", "run.completed"])
precondition(tool.types == ["tool.call"])
print("Swift event sink example passed")
