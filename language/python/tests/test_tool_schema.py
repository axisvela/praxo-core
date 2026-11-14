import unittest

from praxo.model import ToolSpec
from praxo.tool import FuncTool, Registry


class ToolSchemaTests(unittest.TestCase):
    def test_registry_specs_include_parameters_and_risk(self):
        schema = {
            "type": "object",
            "required": ["target"],
            "properties": {"target": {"type": "string"}},
        }
        tool = FuncTool("record", "Record a target.", lambda _args: "recorded")
        tool.parameters = schema
        tool.risk = "write"
        registry = Registry()
        registry.register(tool)

        spec = registry.specs()[0]

        self.assertEqual(spec.name, "record")
        self.assertEqual(spec.parameters, schema)
        self.assertEqual(spec.risk, "write")

    def test_registry_uses_explicit_spec_provider(self):
        class NamedTool:
            name = "named"
            description = "Named tool."

            def spec(self):
                return ToolSpec(
                    name=self.name,
                    description=self.description,
                    parameters={"type": "object", "properties": {}},
                    risk="read",
                )

        registry = Registry()
        registry.register(NamedTool())

        spec = registry.specs()[0]

        self.assertEqual(spec.parameters, {"type": "object", "properties": {}})
        self.assertEqual(spec.risk, "read")


if __name__ == "__main__":
    unittest.main()
