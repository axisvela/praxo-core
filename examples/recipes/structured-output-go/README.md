# Structured Output and Tool Schema Recipe (Go)

This recipe validates model output and tool arguments with the deliberately small
`pkg/tool/jsonschema` subset. It works offline and makes no provider
structured-output claim.

**Evidence level: L1 contract recipe.** It shows application-side validation of
the schema subset. It does not prove every provider honors `ResponseFormat`, nor
does it implement the unsupported JSON Schema keywords (`$ref`, composition,
`additionalProperties`, `format`, and so on). See the
[package documentation](../../../pkg/tool/jsonschema/jsonschema.go) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run 'Structured|Schema|Arguments|ResponseFormat' -v ./...
```

The tests show:

- valid structured output passes;
- an invalid enum value or missing required field fails;
- invalid tool arguments are rejected before the tool effect runs;
- `model.ResponseFormat` carries the same schema to the provider.

Keep the application-side validation even when a provider honors
`ResponseFormat`; provider behavior is integration evidence, not a Core
guarantee. From the repository root,
`python scripts/test_go_structured_output_recipe.py -v` repeats the checks in a
fresh temporary module using the published package.
