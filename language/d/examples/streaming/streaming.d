import std.array : join;
import std.stdio;

void main() {
    string[] chunks = ["status: ", "green"];
    string[] received;
    string output;
    foreach (chunk; chunks) {
        output ~= chunk;
        received ~= chunk;
    }
    assert(output == "status: green");
    assert(received.join("") == output);
    assert(received.length == chunks.length);
    writeln("D streaming example passed");
}
