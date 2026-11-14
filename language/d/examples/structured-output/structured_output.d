import std.stdio;
import praxo.json;
import praxo.jsonschema;

void main() {
    auto schema = parse(`{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}`);
    assert(validate(schema, parse(`{"name":"ok"}`)).length == 0);
    assert(validate(schema, parse(`{}`)).length > 0);
    writeln("D structured output example passed");
}
