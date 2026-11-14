import std.stdio;
import praxo.json;
import praxo.runtime;

void main() {
    auto allow = new CheckpointAllowlist();
    allow.register("order");
    auto data = allow.marshal("order", parse(`{"value":"x"}`));
    auto decoded = allow.unmarshal(data);
    assert(equals(decoded, parse(`{"value":"x"}`)));
    writeln("D checkpoint example passed");
}
