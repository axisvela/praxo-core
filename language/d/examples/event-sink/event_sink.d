import std.stdio;
import praxo.models;
import praxo.runtime;

class RecordingSink : EventSink {
    string[] types;

    void emit(Event event) {
        types ~= event.type;
    }
}

void main() {
    auto all = new RecordingSink();
    auto tool = new RecordingSink();
    auto filter = new FilterSink(tool, delegate bool(Event event) {
        return event.type == "tool.call";
    });
    auto multi = new MultiSink([cast(EventSink) all, filter]);
    foreach (type; ["run.started", "tool.call", "run.completed"]) {
        multi.emit(Event(type, "s1"));
    }
    assert(all.types == ["run.started", "tool.call", "run.completed"]);
    assert(tool.types == ["tool.call"]);
    writeln("D event sink example passed");
}
