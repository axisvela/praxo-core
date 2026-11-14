proc authorize(tenant, role: string, active: bool, tool, target: string): bool =
  active and role == "operator" and tenant == target and tool == "record"

doAssert authorize("acme", "operator", true, "record", "acme")
doAssert not authorize("acme", "viewer", true, "record", "acme")
doAssert not authorize("acme", "operator", true, "record", "other")
echo "Nim identity policy example passed"
