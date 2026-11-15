module test_starter;

import std.stdio : writeln;
import starter : approveScenario, editScenario;

void main() {
    auto approve = approveScenario();
    if (approve.errorCode.length != 0 || approve.output != "done"
        || approve.effects != 1) {
        throw new Error("HITL approve scenario failed");
    }
    auto edit = editScenario();
    if (edit.errorCode != "POLICY_ERROR" || edit.effects != 0) {
        throw new Error("HITL edit scenario failed");
    }
    writeln("D HITL example test passed");
}
