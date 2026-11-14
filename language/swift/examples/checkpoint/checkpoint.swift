import PraxoCore

let allowlist = CheckpointAllowlist()
try allowlist.register("order")
let envelope = try allowlist.marshal("order", ["value": "x"])
let decoded = try allowlist.unmarshal(envelope) as? [String: Any]
precondition(decoded?["value"] as? String == "x")
print("Swift checkpoint example passed")
