import std.stdio;

bool authorize(string tenant, string role, bool active, string tool, string targetTenant) {
    if (!active) return false;
    if (role != "operator") return false;
    if (tenant != targetTenant) return false;
    return tool == "record";
}

void main() {
    assert(authorize("acme", "operator", true, "record", "acme"));
    assert(!authorize("acme", "viewer", true, "record", "acme"));
    assert(!authorize("acme", "operator", true, "record", "other"));
    assert(!authorize("acme", "operator", false, "record", "acme"));
    writeln("D identity policy example passed");
}
