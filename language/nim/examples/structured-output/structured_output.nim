import praxo/json
import praxo/jsonschema

let schema = parseJsonText("""{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}""")
let valid = parseJsonText("""{"name":"ok"}""")
let invalid = parseJsonText("""{}""")
doAssert validateSchema(schema, valid).len == 0
doAssert validateSchema(schema, invalid).len > 0
echo "Nim structured output example passed"
