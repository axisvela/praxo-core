func authorize(tenant: String, role: String, active: Bool, tool: String, target: String) -> Bool {
    active && role == "operator" && tenant == target && tool == "record"
}

precondition(authorize(tenant: "acme", role: "operator", active: true, tool: "record", target: "acme"))
precondition(!authorize(tenant: "acme", role: "viewer", active: true, tool: "record", target: "acme"))
precondition(!authorize(tenant: "acme", role: "operator", active: true, tool: "record", target: "other"))
print("Swift identity policy example passed")
