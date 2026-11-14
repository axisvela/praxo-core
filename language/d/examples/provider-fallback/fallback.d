import std.stdio;

string runFallback(bool primaryFails, bool fallbackFails) {
    if (!primaryFails) return "primary";
    if (!fallbackFails) return "fallback";
    return "MODEL_UNAVAILABLE";
}

void main() {
    assert(runFallback(false, false) == "primary");
    assert(runFallback(true, false) == "fallback");
    assert(runFallback(true, true) == "MODEL_UNAVAILABLE");
    writeln("D provider fallback example passed");
}
