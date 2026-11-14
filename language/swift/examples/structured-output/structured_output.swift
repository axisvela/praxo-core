import PraxoCore

let schema: [String: Any] = [
    "type": "object",
    "required": ["name"],
    "properties": ["name": ["type": "string"]],
]
precondition(JsonSchema.validate(schema, ["name": "ok"]).isEmpty)
precondition(!JsonSchema.validate(schema, [:]).isEmpty)
print("Swift structured output example passed")
