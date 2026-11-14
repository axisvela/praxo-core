import std.stdio;

struct Outcome {
    string output;
    string code;
    int calls;
}

Outcome runRetry(int failures, int max = 3) {
    foreach (attempt; 1 .. max + 1) {
        if (attempt > failures) return Outcome("status: green", null, attempt);
    }
    return Outcome(null, "MODEL_UNAVAILABLE", max);
}

void main() {
    auto recovered = runRetry(2);
    assert(recovered.output == "status: green" && recovered.calls == 3);
    auto exhausted = runRetry(3);
    assert(exhausted.code == "MODEL_UNAVAILABLE" && exhausted.calls == 3);
    writeln("D retry example passed");
}
