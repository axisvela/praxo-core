import praxo/runtime
import praxo/json

let allow = newCheckpointAllowlist()
allow.register("order")
let value = parseJsonText("""{"value":"x"}""")
let data = allow.marshal("order", value)
assert jsonEquals(allow.unmarshal(data), value)
echo "Nim checkpoint example passed"
